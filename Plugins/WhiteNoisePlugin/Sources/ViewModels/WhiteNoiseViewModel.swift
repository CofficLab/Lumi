import Foundation

/// 白噪音播放视图模型。
///
/// 在主线程管理播放状态与定时器，所有音频操作委托给 `NoiseGenerator`。
@MainActor
final class WhiteNoiseViewModel: ObservableObject {
    /// 睡眠定时器可选时长（分钟）。0 表示关闭。
    enum SleepDuration: Int, CaseIterable, Identifiable {
        case off = 0
        case fifteen = 15
        case thirty = 30
        case sixty = 60

        var id: Int { rawValue }

        var title: String {
            rawValue == 0 ? "Off" : "\(rawValue) min"
        }
    }

    @Published var isPlaying = false
    @Published private(set) var errorMessage: String?

    @Published var whiteEnabled = true
    @Published var pinkEnabled = false
    @Published var brownEnabled = false

    @Published var whiteVolume: Float = 0.5
    @Published var pinkVolume: Float = 0.5
    @Published var brownVolume: Float = 0.5

    @Published var masterVolume: Float = 0.8

    @Published var sleepDuration: SleepDuration = .off {
        didSet { restartSleepTimer() }
    }
    @Published private(set) var remainingSeconds: Int?

    private let generator = NoiseGenerator()
    private var sleepTask: Task<Void, Never>?

    init() {
        // 把初始音量/开关同步到生成器。
        syncControlsToGenerator()
    }

    // MARK: - Playback

    func togglePlay() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func start() {
        do {
            try generator.start()
            isPlaying = true
            errorMessage = nil
            restartSleepTimer()
        } catch {
            errorMessage = "Failed to start audio: \(error.localizedDescription)"
        }
    }

    func stop() {
        generator.stop()
        isPlaying = false
        sleepTask?.cancel()
        sleepTask = nil
        remainingSeconds = nil
    }

    // MARK: - Track Controls

    func setEnabled(_ enabled: Bool, for track: NoiseTrack) {
        switch track {
        case .white: whiteEnabled = enabled
        case .pink: pinkEnabled = enabled
        case .brown: brownEnabled = enabled
        }
        generator.setEnabled(enabled, for: track)
    }

    func setVolume(_ volume: Float, for track: NoiseTrack) {
        switch track {
        case .white: whiteVolume = volume
        case .pink: pinkVolume = volume
        case .brown: brownVolume = volume
        }
        generator.setVolume(volume, for: track)
    }

    func setMaster(_ volume: Float) {
        masterVolume = volume
        generator.setMaster(volume)
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Sleep Timer

    private func restartSleepTimer() {
        sleepTask?.cancel()
        sleepTask = nil

        // 未在播放或选择关闭，则不启动倒计时。
        guard isPlaying, let seconds = sleepDurationSeconds() else {
            remainingSeconds = nil
            return
        }

        remainingSeconds = seconds
        sleepTask = Task { [weak self] in
            var left = seconds
            while left > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                left -= 1
                self?.remainingSeconds = left
            }
            self?.stop()
        }
    }

    private func sleepDurationSeconds() -> Int? {
        guard sleepDuration.rawValue > 0 else { return nil }
        return sleepDuration.rawValue * 60
    }

    // MARK: - Private

    private func syncControlsToGenerator() {
        generator.setEnabled(whiteEnabled, for: .white)
        generator.setEnabled(pinkEnabled, for: .pink)
        generator.setEnabled(brownEnabled, for: .brown)
        generator.setVolume(whiteVolume, for: .white)
        generator.setVolume(pinkVolume, for: .pink)
        generator.setVolume(brownVolume, for: .brown)
        generator.setMaster(masterVolume)
    }
}
