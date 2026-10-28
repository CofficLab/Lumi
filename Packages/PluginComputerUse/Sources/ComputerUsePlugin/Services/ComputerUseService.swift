import AppKit
import CoreGraphics
import Foundation
import ProviderMessage
import ScreenCaptureKit

final class ComputerUseService: @unchecked Sendable {
    struct ObservationResult: Sendable {
        let observation: ComputerUseObservation
        let attachment: UserImageAttachment
        let isApplicationAllowed: Bool
    }

    static let shared = ComputerUseService()

    private let stateLock = NSLock()
    private var observations: [UUID: ComputerUseObservation] = [:]
    private var observationOrder: [UUID] = []
    private let authorizationStore: ComputerUseAuthorizationStore
    /// 统一的授权判定器。挂起式授权请求与放行判定都从这里出发。
    private var accessChecker: ComputerUseAccessChecker {
        ComputerUseAccessChecker(authorization: authorizationStore)
    }

    init(authorizationStore: ComputerUseAuthorizationStore = .shared) {
        self.authorizationStore = authorizationStore
    }

    func observe(application: String?, windowTitle: String?) async throws -> ObservationResult {
        guard ComputerUsePermissionService.hasScreenRecordingPermission else {
            throw ComputerUseError.screenRecordingPermissionRequired
        }
        let selection = await MainActor.run { () -> ComputerUseWindow? in
            let windows = ComputerUseWindowProvider.availableWindows()
            let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            return ComputerUseWindowProvider.select(
                from: windows,
                application: application,
                windowTitle: windowTitle,
                frontmostBundleIdentifier: frontmost
            )
        }
        guard let selection else { throw ComputerUseError.noMatchingWindow }
        try requireAuthorized(selection, operation: "observe")
        return try await capture(window: selection)
    }

    /// 校验目标应用是否已获授权。
    ///
    /// 命中未授权应用时抛出携带应用信息的 `authorizationRequired` 错误，
    /// 由工具层转换成挂起回合的授权请求，而不是让整轮直接失败。
    private func requireAuthorized(_ window: ComputerUseWindow, operation: String) throws {
        switch accessChecker.outcome(
            for: window.bundleIdentifier,
            applicationName: window.applicationName
        ) {
        case .allowed:
            return
        case .needsAuthorization(let applicationName, let bundleIdentifier):
            throw ComputerUseError.authorizationRequired(
                applicationName: applicationName,
                bundleIdentifier: bundleIdentifier,
                operation: operation
            )
        case .forbidden(let reason):
            throw ComputerUseError.forbiddenApplication(reason)
        }
    }

    @MainActor
    func act(observationID: UUID, actions: [ComputerUseAction], reason: String) async throws -> ObservationResult {
            guard ComputerUsePermissionService.hasAccessibilityPermission else {
                throw ComputerUseError.accessibilityPermissionRequired
            }
            guard let observation = observation(id: observationID) else {
                throw ComputerUseError.observationNotFound
            }
            try requireAuthorized(observation.window, operation: "act")

            let currentWindow = ComputerUseWindowProvider.availableWindows().first(where: { $0.id == observation.window.id })
            guard let currentWindow,
                  currentWindow.processIdentifier == observation.window.processIdentifier,
                  framesMatch(currentWindow.frame, observation.window.frame),
                  Date().timeIntervalSince(observation.capturedAt) < 60
            else { throw ComputerUseError.staleObservation }

        guard actions.contains(where: \.requiresNativeInput) else {
            for action in actions { try await ComputerUseInputExecutor.execute(action, observation: observation) }
            return try await capture(window: currentWindow)
        }
        guard AccessibilityService.shared.hasRecentInspection(currentWindow.bundleIdentifier) else {
            throw ComputerUseError.invalidArguments("Call accessibility_observe for this application first. Prefer accessibility_act; native input is only a fallback.")
        }
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ComputerUseError.invalidArguments("Explain why Accessibility cannot perform this operation in reason.")
        }
        let coordinator = NativeControlCoordinator.shared
        let session = try await coordinator.acquireWhenAvailable(application: currentWindow.applicationName,
                                              bundleID: currentWindow.bundleIdentifier, reason: reason)
        stateLock.withLock { _ = observations.removeValue(forKey: observationID) }
        defer { coordinator.release(session) }
        let driver = NativeInputDriver(session: session) { [self] in
            guard ComputerUsePermissionService.hasAccessibilityPermission,
                  authorizationStore.isAllowed(currentWindow.bundleIdentifier),
                  authorizationStore.isNativeAllowed(currentWindow.bundleIdentifier) else { throw NativeControlInterruption.stopped }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == currentWindow.processIdentifier,
                  let topWindow = ComputerUseWindowProvider.availableWindows().first(where: { $0.processIdentifier == currentWindow.processIdentifier }),
                  topWindow.id == currentWindow.id,
                  framesMatch(topWindow.frame, currentWindow.frame) else {
                throw NativeControlInterruption.focusChanged
            }
        }
        defer { driver.releaseHeldInput() }
        do {
            try await coordinator.prepare(session)
            guard Date().timeIntervalSince(observation.capturedAt) < 60 else { throw ComputerUseError.staleObservation }
            try coordinator.validateOwner(session)
            NSRunningApplication(processIdentifier: currentWindow.processIdentifier)?.activate(options: [])
            try await Task.sleep(for: .milliseconds(150))
            // 目标窗口遮罩：原生输入路径是**独占桌面**操作，遮罩强度更高，
            // 明确告知用户「这个窗口现在归 Lumi 管」。
            let overlay = beginTargetOverlay(for: currentWindow)
            defer { overlay?.end() }
            for (index, action) in actions.enumerated() {
                try coordinator.validateOwner(session)
                coordinator.updateProgress(computerUseText("Step {current} of {total}", ["current": String(index + 1), "total": String(actions.count)]))
                try await driver.execute(action, observation: observation)
            }
            driver.releaseHeldInput()
            // Release the desktop before screenshot encoding or the next LLM request.
            coordinator.release(session)
            return try await capture(window: currentWindow)
        } catch let interruption as NativeControlInterruption {
            driver.releaseHeldInput()
            switch interruption {
            case .userInput, .focusChanged:
                try await coordinator.waitForUserAfterInterruption(session)
            case .stopped:
                throw ComputerUseError.invalidArguments("Computer operation stopped. Do not retry native input without the user's request.")
            case .timedOut:
                throw ComputerUseError.invalidArguments("Computer operation timed out and released the desktop. Observe the current state before continuing.")
            }
            throw interruption
        }
    }

    func observation(id: UUID) -> ComputerUseObservation? {
        stateLock.withLock { observations[id] }
    }

    // MARK: - 目标窗口遮罩

    /// 在目标窗口上显示「Lumi 正在操作」遮罩。
    ///
    /// 原生输入路径已经用桌面横幅告知了用户，但横幅在**屏幕角落**，
    /// 用户真正盯着的目标窗口上没有任何提示。遮罩把提示搬到用户视线所及之处。
    ///
    /// - Note: 几何查询失败不阻断操作：遮罩是提示，不是操作的前置条件。
    ///
    /// - Returns: 已启动的遮罩会话；无法定位窗口时返回 `nil`。
    @MainActor
    private func beginTargetOverlay(for window: ComputerUseWindow) -> ComputerUseTargetOverlayController? {
        guard let rect = ComputerUseTargetGeometryProvider.quartzRect(forWindowID: window.id) else {
            return nil
        }
        let controller = ComputerUseTargetOverlayController.shared
        controller.begin(
            ComputerUseTargetOverlayController.Target(
                quartzRect: rect,
                applicationName: window.applicationName,
                intensity: .blocking
            )
        )
        return controller
    }

    func isApplicationAllowed(for observationID: UUID) -> Bool {
        guard let observation = observation(id: observationID) else { return false }
        return authorizationStore.isAllowed(observation.window.bundleIdentifier)
    }

    private func capture(window: ComputerUseWindow) async throws -> ObservationResult {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let shareableWindow = content.windows.first(where: { $0.windowID == window.id }) else {
            throw ComputerUseError.captureFailed
        }
        let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int((filter.contentRect.width * CGFloat(filter.pointPixelScale)).rounded()))
        configuration.height = max(1, Int((filter.contentRect.height * CGFloat(filter.pointPixelScale)).rounded()))
        configuration.showsCursor = true
        let image: CGImage = try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: ComputerUseError.captureFailed)
                }
            }
        }
        let encoded = try ComputerUseImageEncoder.encode(image)
        let observation = ComputerUseObservation(
            window: window,
            imageWidth: encoded.width,
            imageHeight: encoded.height
        )
        store(observation)
        return ObservationResult(
            observation: observation,
            attachment: encoded.attachment,
            isApplicationAllowed: authorizationStore.isAllowed(window.bundleIdentifier)
        )
    }

    private func store(_ observation: ComputerUseObservation) {
        stateLock.withLock {
            observations[observation.id] = observation
            observationOrder.append(observation.id)
            while observationOrder.count > 12 {
                observations.removeValue(forKey: observationOrder.removeFirst())
            }
        }
    }

    private func framesMatch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 2
            && abs(lhs.minY - rhs.minY) < 2
            && abs(lhs.width - rhs.width) < 2
            && abs(lhs.height - rhs.height) < 2
    }
}
