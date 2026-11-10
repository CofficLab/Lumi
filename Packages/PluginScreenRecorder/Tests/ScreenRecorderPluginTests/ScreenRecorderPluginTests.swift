import Foundation
import KitAgentTool
import Testing
@testable import ScreenRecorderPlugin

@Suite("ScreenRecorderPlugin")
struct ScreenRecorderPluginTests {
    @Test("Models initialize")
    func modelsInitialize() {
        let config = RecordingConfig(
            target: .appWindow(application: "Maps", windowTitle: nil),
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )
        let session = RecordingSession(config: config, targetDescription: "Maps")
        #expect(session.isActive == false)
        #expect(config.frameRate == 30)
    }

    @Test("frameRate 被钳制到 1...60")
    func frameRateClamping() {
        let tooHigh = RecordingConfig(target: .display(), frameRate: 120, outputDirectory: URL(fileURLWithPath: "/tmp"))
        #expect(tooHigh.frameRate == 60)
        let tooLow = RecordingConfig(target: .display(), frameRate: 0, outputDirectory: URL(fileURLWithPath: "/tmp"))
        #expect(tooLow.frameRate == 1)
    }

    @Test("分辨率高度与时长被钳制到安全范围")
    func resolutionHeightAndDurationClamping() {
        let tooHigh = RecordingConfig(
            target: .display(),
            resolutionHeight: Int.max,
            maxDurationSeconds: Int.max,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(tooHigh.resolutionHeight == RecordingConfig.maxResolutionHeight)
        #expect(tooHigh.maxDurationSeconds == RecordingConfig.maxDurationLimit)

        let tooLow = RecordingConfig(
            target: .display(),
            resolutionHeight: -1,
            maxDurationSeconds: -5,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(tooLow.resolutionHeight == 1)
        #expect(tooLow.maxDurationSeconds == 1)
    }

    @Test("错误描述非空")
    func errorDescriptions() {
        #expect((RecordingError.permissionDenied.errorDescription ?? "").isEmpty == false)
        #expect((RecordingError.targetIsLumi.errorDescription ?? "").isEmpty == false)
        #expect((RecordingError.notRecording.errorDescription ?? "").isEmpty == false)
        #expect((RecordingError.microphoneUnsupported.errorDescription ?? "").isEmpty == false)
    }

    // MARK: - 回归 #757：麦克风采集的系统版本门槛

    @Test("麦克风采集仅在 macOS 15+ 视为可用")
    func microphoneCapabilityDependsOnMajorVersion() {
        #expect(RecordingMicrophoneCapability.isSupported(majorVersion: 14) == false)
        #expect(RecordingMicrophoneCapability.isSupported(majorVersion: 15))
        #expect(RecordingMicrophoneCapability.isSupported(majorVersion: 26))
    }

    @Test("macOS 14 请求麦克风时明确报错，未请求则放行")
    func microphoneValidationRejectsUnsupportedVersions() throws {
        #expect(throws: RecordingError.self) {
            try RecordingMicrophoneCapability.validate(includeMicrophone: true, majorVersion: 14)
        }
        // 不请求麦克风时版本不影响录制。
        try RecordingMicrophoneCapability.validate(includeMicrophone: false, majorVersion: 14)
        // macOS 15+ 正常通过。
        try RecordingMicrophoneCapability.validate(includeMicrophone: true, majorVersion: 15)
    }

    @MainActor
    @Test("macOS 14 上 start 在权限检查前就拒绝麦克风录制")
    func startRejectsMicrophoneBeforePermissionsOnMacOS14() async {
        let manager = RecordingSessionManager()
        manager.osMajorVersionProvider = { 14 }
        let config = RecordingConfig(
            target: .display(),
            includeMicrophone: true,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )

        do {
            try await manager.start(config: config)
            Issue.record("Expected start to reject microphone capture on macOS 14")
        } catch let error as RecordingError {
            guard case .microphoneUnsupported = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
        #expect(manager.hasActiveSession == false)
    }

    @MainActor
    @Test("新版工具保留录制契约")
    func v2ToolsPreserveRecordingContract() {
        let plugin = ScreenRecorderPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.screen-recorder")
        #expect(StartRecordingV2Tool.toolName == "start_recording")
        #expect(StopRecordingV2Tool.toolName == "stop_recording")
        #expect(ListRecordableAppsV2Tool.toolName == "list_recordable_apps")
    }

    /// 回归：缺参曾经返回字符串，默认 `executeResult` 会当成成功结果。
    @MainActor
    @Test("缺少 application 时抛出而不是返回错误字符串")
    func startRecordingThrowsWhenApplicationIsMissing() async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await StartRecordingV2Tool().executeResult(arguments: ["target": ToolArgument("app_window")])
        }
    }
}
