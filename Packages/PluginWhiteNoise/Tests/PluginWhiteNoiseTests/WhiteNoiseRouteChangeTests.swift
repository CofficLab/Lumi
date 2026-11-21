import AVFoundation
import Foundation
import Testing
@testable import PluginWhiteNoise

/// 回归 #455：输出设备/采样率变化令 `AVAudioEngine` 自动停止后，
/// 噪声永久静音而 UI 仍显示「播放中」。
@Suite("WhiteNoise 路由变化恢复", .serialized)
struct WhiteNoiseRouteChangeTests {

    @Test("配置变化通知后用户仍期望播放则自动重启引擎")
    func configurationChangeRestartsEngineWhileUserWantsPlayback() throws {
        let generator = NoiseGenerator()
        try generator.start()
        defer { generator.stop() }
        #expect(generator.isRunning)

        // 模拟硬件打断：路由/采样率变化会令引擎自动停止，通知随后到达。
        generator.engine.stop()
        #expect(!generator.isRunning)

        // 发布真实的配置变化通知（观察者在发布线程同步执行）。
        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: generator.engine
        )
        #expect(generator.isRunning, "用户仍期望播放时引擎必须自动恢复（#455）")
    }

    @Test("用户主动停止后配置变化不得自动重启")
    func userStopDoesNotResumeOnConfigurationChange() throws {
        let generator = NoiseGenerator()
        try generator.start()
        generator.stop()

        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: generator.engine
        )
        #expect(!generator.isRunning, "用户主动停止后路由变化不得自动重启（#455）")
    }

    @MainActor
    @Test("无法恢复时 UI 同步为停止态且睡眠倒计时被取消")
    func playbackLostSynchronizesUIToStopped() async throws {
        let generator = NoiseGenerator()
        let viewModel = WhiteNoiseViewModel(generator: generator)
        viewModel.start()
        #expect(viewModel.isPlaying)

        // 恢复失败路径（真实场景由 handleConfigurationChange 内 start 抛错触发）：
        // 生成器回调 onPlaybackLost，ViewModel 必须把 UI 同步为停止态。
        generator.onPlaybackLost?()
        try await Task.sleep(for: .milliseconds(100))

        #expect(!viewModel.isPlaying, "无法恢复时 UI 必须同步为停止态，单击即可重新开始（#455）")
        #expect(viewModel.remainingSeconds == nil, "中断后睡眠倒计时必须一并取消（#455）")
    }
}
