import Foundation
import ScreenCaptureKit
import Testing
@testable import ScreenRecorderPlugin

/// 回归 #851：测试录制反馈只能显示本轮会话真正产生的结果。
/// 新会话启动必须清除上一轮 `lastResult`；反馈须校验会话 ID 与 `.finished`
/// 状态，失败时显示本轮错误，绝不把上一轮成功伪装成本轮成功。
@MainActor
@Suite("Recording test feedback session scoping (#851)")
struct RecordingTestFeedbackTests {

    /// 引擎桩：start 空操作成功，用于建立活动会话而不触碰真实采集。
    private final class IdleRecorder: RecordingEngine, @unchecked Sendable {
        var onError: (@Sendable (Error) -> Void)?
        @MainActor
        func start(filter: SCContentFilter, config: RecordingConfig, tempOutputURL: URL) async throws {}
        func stop() async throws -> ScreenCaptureRecorder.Output { throw RecordingError.notRecording }
        func cancel() async {}
    }

    private func makeConfig() -> RecordingConfig {
        RecordingConfig(
            target: .display(),
            outputDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    private func result(_ name: String) -> RecordingResult {
        RecordingResult(
            outputURL: URL(fileURLWithPath: "/tmp/\(name)"),
            durationSeconds: 3,
            fileSizeBytes: 1,
            width: 1920,
            height: 1080
        )
    }

    @Test("新会话启动清除上一轮 lastResult（#851）")
    func startClearsPreviousResult() async throws {
        let manager = RecordingSessionManager()
        manager.screenRecordingPermissionProvider = { true }
        manager.targetResolver = { _ in (SCContentFilter(), "Stub", nil) }
        manager.recorderFactory = { IdleRecorder() }
        // 模拟上一轮成功录制留下的结果。
        manager.lastResult = result("old.mp4")

        try await manager.start(config: makeConfig())
        #expect(manager.lastResult == nil, "新会话启动必须清除上一轮结果")
        await manager.cancel()
    }

    @Test("本轮 finished 会话显示已保存（#851）")
    func feedbackShowsSavedForMatchingFinishedSession() {
        let id = UUID()
        let session = RecordingSession(
            id: id, config: makeConfig(), state: .finished,
            outputURL: URL(fileURLWithPath: "/tmp/new.mp4")
        )
        let msg = ScreenRecorderSettingsView.testFeedback(
            session: session, expectedSessionID: id, lastResult: result("new.mp4")
        )
        #expect(msg?.contains("new.mp4") == true)
    }

    @Test("本轮 error 会话显示错误而非上一轮已保存（#851）")
    func feedbackShowsErrorNotStaleSaved() {
        let id = UUID()
        let session = RecordingSession(
            id: id, config: makeConfig(), state: .error, error: "capture failed"
        )
        // 即便上一轮成功结果仍在，失败的本轮也不得复用它。
        let msg = ScreenRecorderSettingsView.testFeedback(
            session: session, expectedSessionID: id, lastResult: result("old.mp4")
        )
        #expect(msg == "capture failed")
        #expect(msg?.contains("old.mp4") != true)
    }

    @Test("会话 ID 不符时不复用结果（#851）")
    func feedbackIgnoresMismatchedSessionID() {
        let session = RecordingSession(
            id: UUID(), config: makeConfig(), state: .finished,
            outputURL: URL(fileURLWithPath: "/tmp/other.mp4")
        )
        let msg = ScreenRecorderSettingsView.testFeedback(
            session: session, expectedSessionID: UUID(), lastResult: result("other.mp4")
        )
        #expect(msg == nil)
    }
}