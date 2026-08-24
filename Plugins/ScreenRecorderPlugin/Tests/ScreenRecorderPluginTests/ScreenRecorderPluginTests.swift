import Foundation
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

    @Test("错误描述非空")
    func errorDescriptions() {
        #expect((RecordingError.permissionDenied.errorDescription ?? "").isEmpty == false)
        #expect((RecordingError.targetIsLumi.errorDescription ?? "").isEmpty == false)
        #expect((RecordingError.notRecording.errorDescription ?? "").isEmpty == false)
    }

    @MainActor
    @Test("新版工具保留录制契约")
    func v2ToolsPreserveRecordingContract() {
        let plugin = ScreenRecorderSuperPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.screen-recorder")
        #expect(StartRecordingV2Tool.toolName == "start_recording")
        #expect(StopRecordingV2Tool.toolName == "stop_recording")
        #expect(ListRecordableAppsV2Tool.toolName == "list_recordable_apps")
    }
}
