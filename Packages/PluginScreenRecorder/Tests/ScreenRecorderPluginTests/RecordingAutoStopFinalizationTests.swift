import CoreGraphics
import Foundation
import ScreenCaptureKit
import Testing
@testable import ScreenRecorderPlugin

/// 回归 #377：自动停止（计时到期 / 目标窗口消失）不得在「已取消自身」的计时器 Task
/// 内执行落盘。`stop()` 里的 `cancelTimers()` 会取消正在调用它的计时器 Task，Swift 的
/// 取消状态跨 `await` 保留，`RecordingFileWriter.finalize` 入口的 `Task.checkCancellation()`
/// 随即抛 `CancellationError`，自动停止进入 error 态且目标目录没有最终 MP4（录制丢失）。
/// 修复后自动停止在独立 Task 中执行 `stop()`，落盘正常完成。
@MainActor
@Suite("RecordingSessionManager 自动停止落盘（#377）")
struct RecordingAutoStopFinalizationTests {

    /// 引擎桩：start 写占位文件，stop 返回可落盘的摘要（对齐 ShutdownTests）。
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

    private func makeManager() -> RecordingSessionManager {
        let manager = RecordingSessionManager()
        manager.screenRecordingPermissionProvider = { true }
        manager.recorderFactory = { FinalizingRecorder() }
        return manager
    }

    private func makeOutputDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("screen-recorder-autostop-\(UUID().uuidString)", isDirectory: true)
    }

    /// 等待自动停止收尾（最多 ~5s）。修复前后 hasActiveSession 都会变 false
    /// （finished / error 均非活跃），区分点在 state 与落盘结果。
    private func waitUntilInactive(_ manager: RecordingSessionManager) async throws {
        let deadline = Date().addingTimeInterval(5)
        while manager.hasActiveSession, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func expectFinalized(_ manager: RecordingSessionManager, outputDir: URL) {
        #expect(manager.hasActiveSession == false)
        #expect(manager.currentSession?.state == .finished)
        #expect(manager.currentSession?.outputURL != nil)
        #expect(manager.lastResult != nil)
        let files = (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? []
        #expect(files.contains { $0.pathExtension == "mp4" })
    }

    @Test("计时到期自动停止必须落盘为 finished，不得因自取消进入 error（#377）")
    func maxDurationAutoStopFinalizesRecording() async throws {
        let manager = makeManager()
        manager.targetResolver = { _ in (SCContentFilter(), "Stub", nil) }
        let outputDir = makeOutputDir()
        defer { try? FileManager.default.removeItem(at: outputDir) }
        let config = RecordingConfig(
            target: .display(),
            maxDurationSeconds: 1,
            outputDirectory: outputDir
        )

        try await manager.start(config: config)
        #expect(manager.hasActiveSession)

        try await waitUntilInactive(manager)
        expectFinalized(manager, outputDir: outputDir)
    }

    @Test("目标窗口消失自动停止必须落盘为 finished，不得因自取消进入 error（#377）")
    func windowGoneAutoStopFinalizesRecording() async throws {
        let manager = makeManager()
        // 注入一个不存在的窗口 id：windowExists 定向查询必然返回 false，
        // 存活检测在首个轮询周期即触发自动停止。
        let ghostWindow = RecordableWindow(
            id: CGWindowID.max,
            processIdentifier: -1,
            bundleIdentifier: "com.example.stub",
            applicationName: "Stub",
            windowTitle: "",
            frame: CGRect(x: 0, y: 0, width: 200, height: 200)
        )
        manager.targetResolver = { _ in (SCContentFilter(), "Stub", ghostWindow) }
        let outputDir = makeOutputDir()
        defer { try? FileManager.default.removeItem(at: outputDir) }
        let config = RecordingConfig(
            target: .appWindow(application: "Stub", windowTitle: nil),
            outputDirectory: outputDir
        )

        try await manager.start(config: config)
        #expect(manager.hasActiveSession)

        try await waitUntilInactive(manager)
        expectFinalized(manager, outputDir: outputDir)
    }
}