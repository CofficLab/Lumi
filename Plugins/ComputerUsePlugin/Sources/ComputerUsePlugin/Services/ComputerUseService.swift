import AppKit
import CoreGraphics
import Foundation
import KernelLumi
import ScreenCaptureKit

actor ComputerUseActionGate {
    func perform<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        try await operation()
    }
}

final class ComputerUseService: @unchecked Sendable {
    struct ObservationResult: Sendable {
        let observation: ComputerUseObservation
        let attachment: LumiImageAttachment
        let isApplicationAllowed: Bool
    }

    static let shared = ComputerUseService()

    private let stateLock = NSLock()
    private var observations: [UUID: ComputerUseObservation] = [:]
    private var observationOrder: [UUID] = []
    private let actionGate = ComputerUseActionGate()
    private let authorizationStore: ComputerUseAuthorizationStore

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
        guard authorizationStore.isAllowed(selection.bundleIdentifier) else {
            throw ComputerUseError.applicationNotAllowed(selection.applicationName)
        }
        return try await capture(window: selection)
    }

    func act(observationID: UUID, actions: [ComputerUseAction]) async throws -> ObservationResult {
        try await actionGate.perform { [self] in
            guard ComputerUsePermissionService.hasAccessibilityPermission else {
                throw ComputerUseError.accessibilityPermissionRequired
            }
            guard let observation = observation(id: observationID) else {
                throw ComputerUseError.observationNotFound
            }
            guard authorizationStore.isAllowed(observation.window.bundleIdentifier) else {
                throw ComputerUseError.applicationNotAllowed(observation.window.applicationName)
            }

            let currentWindow = await MainActor.run {
                ComputerUseWindowProvider.availableWindows().first(where: { $0.id == observation.window.id })
            }
            guard let currentWindow,
                  currentWindow.processIdentifier == observation.window.processIdentifier,
                  framesMatch(currentWindow.frame, observation.window.frame)
            else { throw ComputerUseError.staleObservation }

            _ = await MainActor.run {
                NSRunningApplication(processIdentifier: currentWindow.processIdentifier)?
                    .activate(options: [])
            }
            try await Task.sleep(for: .milliseconds(120))
            for action in actions {
                try Task.checkCancellation()
                try await ComputerUseInputExecutor.execute(action, observation: observation)
            }
            try await Task.sleep(for: .milliseconds(180))

            let updatedWindow = await MainActor.run {
                ComputerUseWindowProvider.availableWindows().first(where: { $0.id == currentWindow.id })
            }
            guard let updatedWindow else { throw ComputerUseError.staleObservation }
            return try await capture(window: updatedWindow)
        }
    }

    func observation(id: UUID) -> ComputerUseObservation? {
        stateLock.withLock { observations[id] }
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
