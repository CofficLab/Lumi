import Foundation
import KernelCore
import ScreenCaptureKit
import Testing
@testable import ScreenRecorderPlugin

/// 回归 #223：onShutdown 必须停止并落盘活动录制、取消计时器、清理会话并隐藏指示器。
/// 单例不随插件生命周期结束，旧实现只注销工具 / 观察者 / 设置页，
/// 禁用插件后采集仍继续，而 stop 工具已被移除，用户既不能停止也观察不到。
@Suite("ScreenRecorder 插件关闭", .serialized)
@MainActor
struct ScreenRecorderPluginShutdownTests {

    /// 引擎桩：start 写占位文件，stop 返回可落盘的摘要。
    private final class FinalizingRecorder: RecordingEngine, @unchecked Sendable {
        var onError: (@Sendable (Error) -> Void)?
        private var tempURL: URL?
        @MainActor
        func start(filter: SCContentFilter, config: RecordingConfig, tempOutputURL: URL) async throws {
            tempURL = tempOutputURL
            try Data("stub".utf8).write(to: tempOutputURL)
        }
        func stop() async throws -> ScreenCaptureRecorder.Output {
            guard let tempURL else { throw RecordingError.notRecording }
            return .init(url: tempURL, width: 2, height: 2)
        }
        func cancel() async {
            if let tempURL { try? FileManager.default.removeItem(at: tempURL) }
        }
    }

    /// 引擎桩：stop 总是失败，验证关闭时回退取消、会话不得残留活跃态。
    private final class FailingStopRecorder: RecordingEngine, @unchecked Sendable {
        var onError: (@Sendable (Error) -> Void)?
        @MainActor
        func start(filter: SCContentFilter, config: RecordingConfig, tempOutputURL: URL) async throws {}
        func stop() async throws -> ScreenCaptureRecorder.Output {
            throw RecordingError.encodingFailed("stop failed")
        }
        func cancel() async {}
    }

    private func makeManager() -> RecordingSessionManager {
        let manager = RecordingSessionManager.shared
        manager.screenRecordingPermissionProvider = { true }
        manager.targetResolver = { _ in (SCContentFilter(), "Stub", nil) }
        return manager
    }

    /// 等待 fire-and-forget 关闭 Task 收尾（最多 ~2s）。修复前录制永远不会
    /// 被停止，循环耗尽后断言失败（RED）。
    private func waitUntilInactive(_ manager: RecordingSessionManager) async throws {
        let deadline = Date().addingTimeInterval(2)
        while manager.hasActiveSession, Date() < deadline {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    @Test("关闭时停止并落盘活动录制，隐藏指示器（#223）")
    func shutdownStopsAndFinalizesActiveRecording() async throws {
        let manager = makeManager()
        manager.recorderFactory = { FinalizingRecorder() }
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("screen-recorder-shutdown-\(UUID().uuidString)", isDirectory: true)
        let config = RecordingConfig(target: .display(), outputDirectory: outputDir)
        try await manager.start(config: config)
        #expect(manager.hasActiveSession)
        RecordingIndicatorController.shared.show(description: "Stub")

        let plugin = ScreenRecorderPlugin()
        try plugin.onShutdown(kernel: KernelCoreContainer())
        try await waitUntilInactive(manager)

        #expect(manager.hasActiveSession == false)
        #expect(manager.currentSession?.state == .finished)
        #expect(manager.currentSession?.outputURL != nil)
        #expect(RecordingIndicatorController.shared.isVisible == false)
        let files = (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? []
        #expect(files.contains { $0.pathExtension == "mp4" })
        try? FileManager.default.removeItem(at: outputDir)
    }

    @Test("关闭时 stop 失败则回退取消，会话不得残留活跃态（#223）")
    func shutdownFallsBackToCancelWhenStopFails() async throws {
        let manager = makeManager()
        manager.recorderFactory = { FailingStopRecorder() }
        let config = RecordingConfig(
            target: .display(),
            outputDirectory: FileManager.default.temporaryDirectory
        )
        try await manager.start(config: config)
        #expect(manager.hasActiveSession)
        RecordingIndicatorController.shared.show(description: "Stub")

        try ScreenRecorderPlugin().onShutdown(kernel: KernelCoreContainer())
        try await waitUntilInactive(manager)

        #expect(manager.hasActiveSession == false)
        #expect(manager.currentSession?.state == .error)
        #expect(RecordingIndicatorController.shared.isVisible == false)
    }

    @Test("无活动录制时关闭也隐藏指示器（#223）")
    func shutdownWithoutRecordingHidesIndicator() async throws {
        let manager = makeManager()
        #expect(manager.hasActiveSession == false)
        RecordingIndicatorController.shared.show(description: "Stub")

        try ScreenRecorderPlugin().onShutdown(kernel: KernelCoreContainer())

        // 指示器在同步路径上隐藏，不依赖异步清理 Task。
        #expect(RecordingIndicatorController.shared.isVisible == false)
        #expect(manager.hasActiveSession == false)
    }
}