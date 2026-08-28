import AppKit
import Foundation
import os
import ScreenCaptureKit

/// 录制会话管理器：跨多轮对话存活的单例，编排「校验权限 → 解析目标 → 启动引擎 →
/// 计时/自动停/存活检测 → 停止落盘 → 广播状态」全流程。
///
/// 设计与 `ComputerUseService` / `MindMapStore` 一致：`@MainActor ObservableObject`
/// 单例，工具只是向它发命令。状态变化通过 `NotificationCenter` 广播
/// `.lumiRecordingStateChanged`（携带 `RecordingActivity`），供浮层指示器等订阅。
@MainActor
public final class RecordingSessionManager: ObservableObject {
    public static let shared = RecordingSessionManager()
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.screen-recorder")

    @Published public private(set) var currentSession: RecordingSession?
    @Published public private(set) var elapsedSeconds: Int = 0

    private var recorder: ScreenCaptureRecorder?
    private var resolvedWindow: RecordableWindow?
    private var elapsedTimer: Task<Void, Never>?
    private var survivalPollTask: Task<Void, Never>?
    private var isStopping = false

    public var hasActiveSession: Bool { currentSession?.isActive == true }
    public var lastResult: RecordingResult?

    public init() {}

    // MARK: - Start

    /// 启动一次录制。
    ///
    /// `config.outputDirectory` 必须由调用方（工具）预先用 `kernel.isPathAllowed` 校验。
    public func start(config: RecordingConfig) async throws {
        // 1) 权限。
        guard RecordingPermissionService.hasScreenRecordingPermission else {
            RecordingPermissionService.requestScreenRecordingPermission()
            throw RecordingError.permissionDenied
        }
        if config.includeMicrophone, !RecordingPermissionService.hasMicrophonePermission {
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                RecordingPermissionService.requestMicrophonePermission { cont.resume(returning: $0) }
            }
            if !granted { throw RecordingError.microphonePermissionDenied }
        }

        // 2) 互斥：同一时刻仅一个活跃会话。
        if hasActiveSession {
            throw RecordingError.alreadyRecording(currentSession?.targetDescription ?? "")
        }

        // 3) 解析目标 → 过滤器。
        let (filter, targetDescription, window) = try await resolveTarget(for: config)
        if let window { RecordableWindowProvider.activate(window) }

        // 4) 准备引擎与临时文件。
        currentSession = nil
        elapsedSeconds = 0
        resolvedWindow = window
        let tempURL = RecordingFileWriter.tempURL(for: config.sessionID, in: ScreenRecorderRuntime.dataDirectory)
        let recorder = ScreenCaptureRecorder()
        recorder.onError = { [weak self] error in
            Task { @MainActor in self?.handleStreamError(error) }
        }
        self.recorder = recorder

        do {
            try await recorder.start(filter: filter, config: config, tempOutputURL: tempURL)
        } catch {
            RecordingFileWriter.removeTempFile(at: tempURL)
            self.recorder = nil
            resolvedWindow = nil
            throw error
        }

        // 5) 进入录制态。
        currentSession = RecordingSession(
            id: config.sessionID,
            config: config,
            state: .recording,
            targetDescription: targetDescription
        )
        startTimers(for: config, window: window)
        postActivity(state: .recording)
        RecordingIndicatorController.shared.show(description: targetDescription)
        Self.logger.info("recording started: \(targetDescription, privacy: .public) → \(config.outputDirectory.path, privacy: .public)")
    }

    // MARK: - Stop

    /// 停止录制并落盘。停止幂等：重复调用或无活跃录制时抛 `.notRecording`。
    public func stop() async throws -> RecordingResult {
        guard hasActiveSession, let session = currentSession, let recorder else {
            throw RecordingError.notRecording
        }
        guard !isStopping else { throw RecordingError.notRecording }
        isStopping = true
        defer { isStopping = false }

        cancelTimers()
        currentSession?.state = .stopping
        postActivity(state: .stopping)

        do {
            let output = try await recorder.stop()
            let finalURL = try await RecordingFileWriter.finalize(
                tempURL: output.url,
                to: session.config.outputDirectory,
                filename: session.config.filename
            )
            let attrs = try? FileManager.default.attributesOfItem(atPath: finalURL.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let duration = max(0, elapsedSeconds)
            let result = RecordingResult(
                outputURL: finalURL,
                durationSeconds: duration,
                fileSizeBytes: size,
                width: output.width,
                height: output.height
            )
            lastResult = result
            currentSession?.state = .finished
            currentSession?.outputURL = finalURL
            postActivity(state: .finished, outputPath: finalURL.path)
            RecordingIndicatorController.shared.hide()
            self.recorder = nil
            resolvedWindow = nil
            Self.logger.info("recording finished: \(finalURL.path, privacy: .public) (\(result.durationSeconds)s)")
            return result
        } catch {
            currentSession?.state = .error
            currentSession?.error = error.localizedDescription
            postActivity(state: .error, error: error.localizedDescription)
            RecordingIndicatorController.shared.hide()
            self.recorder = nil
            resolvedWindow = nil
            Self.logger.error("recording failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// 取消（异常/取消回滚），不保证落盘。
    public func cancel() async {
        cancelTimers()
        RecordingIndicatorController.shared.hide()
        await recorder?.cancel()
        recorder = nil
        resolvedWindow = nil
        if currentSession?.isActive == true {
            currentSession?.state = .error
            postActivity(state: .error, error: "cancelled")
        }
    }

    // MARK: - Target resolution

    private func resolveTarget(for config: RecordingConfig) async throws -> (filter: SCContentFilter, description: String, window: RecordableWindow?) {
        switch config.target {
        case .appWindow(let application, let windowTitle):
            let app = application.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !app.isEmpty else { throw RecordingError.noSuchWindow(application) }

            let windows = RecordableWindowProvider.availableWindows()
            var window = RecordableWindowProvider.select(
                from: windows,
                application: app,
                windowTitle: windowTitle,
                frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            )
            if window == nil {
                window = try await RecordableWindowProvider.launchIfNeeded(application: app, windowTitle: windowTitle)
            }
            guard let window else { throw RecordingError.noSuchWindow(app) }
            guard window.bundleIdentifier != RecordableWindowProvider.lumiBundleIdentifier else {
                throw RecordingError.targetIsLumi
            }

            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == window.id }) else {
                throw RecordingError.noSuchWindow(app)
            }
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            return (filter, window.applicationName, window)

        case .display(let excludeLumi):
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                throw RecordingError.encodingFailed("no display available")
            }
            let lumiApps = excludeLumi
                ? content.applications.filter { $0.bundleIdentifier == RecordableWindowProvider.lumiBundleIdentifier }
                : []
            let filter = SCContentFilter(display: display, excludingApplications: lumiApps, exceptingWindows: [])
            return (filter, "Display", nil)
        }
    }

    // MARK: - Timers

    private func startTimers(for config: RecordingConfig, window: RecordableWindow?) {
        let maxDuration = config.maxDurationSeconds
        elapsedTimer = Task { @MainActor [weak self] in
            while !Task.isCancelled, self?.hasActiveSession == true {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                guard let self, self.hasActiveSession else { break }
                self.elapsedSeconds += 1
                RecordingIndicatorController.shared.update(elapsed: self.elapsedSeconds)
                if let maxDuration, self.elapsedSeconds >= maxDuration {
                    _ = try? await self.stop()
                    return
                }
            }
        }
        if let window {
            survivalPollTask = Task { @MainActor [weak self] in
                while !Task.isCancelled, self?.hasActiveSession == true {
                    try? await Task.sleep(for: .milliseconds(1000))
                    if Task.isCancelled { break }
                    guard let self, self.hasActiveSession else { break }
                    let stillPresent = RecordableWindowProvider.availableWindows().contains { $0.id == window.id }
                    if !stillPresent {
                        _ = try? await self.stop()
                        return
                    }
                }
            }
        }
    }

    private func cancelTimers() {
        elapsedTimer?.cancel(); elapsedTimer = nil
        survivalPollTask?.cancel(); survivalPollTask = nil
    }

    // MARK: - Stream error

    private func handleStreamError(_ error: Error) {
        guard hasActiveSession else { return }
        cancelTimers()
        currentSession?.state = .error
        currentSession?.error = error.localizedDescription
        postActivity(state: .error, error: error.localizedDescription)
        RecordingIndicatorController.shared.hide()
        Task { await recorder?.cancel() }
        recorder = nil
        resolvedWindow = nil
    }

    // MARK: - Broadcast

    private func postActivity(state: RecordingActivity.State, outputPath: String? = nil, error: String? = nil) {
        let activity = RecordingActivity(
            state: state,
            sessionID: currentSession?.id,
            targetDescription: currentSession?.targetDescription,
            elapsedSeconds: elapsedSeconds,
            outputPath: outputPath,
            error: error
        )
        NotificationCenter.default.post(
            name: .lumiRecordingStateChanged,
            object: nil,
            userInfo: [RecordingActivityNotification.activityKey: activity]
        )
    }
}
