import CoreMedia
import Foundation
import ScreenCaptureKit
import Testing
@testable import ScreenRecorderPlugin

/// 回归 #819：`include_app_audio: true` 只注册了 `.audio` 输出，却从未打开
/// `SCStreamConfiguration.capturesAudio` 总开关（默认 false）。ScreenCaptureKit
/// 因此不投递应用音频样本，录制沿成功路径完成但静默缺少用户明确要求的声音。
@Suite("录制流配置 (#819)")
struct ScreenCaptureConfigurationTests {

    @Test("请求应用音频时必须打开 capturesAudio 总开关（回归 #819）")
    func appAudioEnablesCapturesAudio() {
        let config = RecordingConfig(
            target: .display(),
            includeAppAudio: true,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )

        let streamConfig = ScreenCaptureRecorder.makeStreamConfiguration(
            config: config, width: 1920, height: 1080, captureMicrophone: false
        )

        #expect(streamConfig.capturesAudio == true)
    }

    @Test("未请求应用音频时 capturesAudio 不得被打开")
    func withoutAppAudioCapturesAudioStaysOff() {
        let config = RecordingConfig(
            target: .display(),
            includeAppAudio: false,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )

        let streamConfig = ScreenCaptureRecorder.makeStreamConfiguration(
            config: config, width: 1920, height: 1080, captureMicrophone: false
        )

        #expect(streamConfig.capturesAudio == false)
    }

    @Test("流配置保留尺寸/光标/帧率，麦克风开关按解析结果设置")
    func preservesDimensionsAndMicrophoneFlag() {
        let config = RecordingConfig(
            target: .display(),
            frameRate: 24,
            includeAppAudio: true,
            showCursor: false,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )

        let streamConfig = ScreenCaptureRecorder.makeStreamConfiguration(
            config: config, width: 1280, height: 720, captureMicrophone: true
        )

        #expect(streamConfig.width == 1280)
        #expect(streamConfig.height == 720)
        #expect(streamConfig.showsCursor == false)
        #expect(streamConfig.minimumFrameInterval == CMTime(value: 1, timescale: 24))
        #expect(streamConfig.capturesAudio == true)
        if #available(macOS 15.0, *) {
            #expect(streamConfig.captureMicrophone == true)
        }
    }
}