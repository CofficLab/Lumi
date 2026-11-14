import AVFoundation
import Foundation
import os

/// 一个基于 `os_unfair_lock` 的轻量同步盒子。
///
/// `OSAllocatedUnfairLock` 在不同 SDK 版本间 API 不一致，这里直接封装 C 层
/// `os_unfair_lock`，它在 Apple 全平台可用、非公平自旋、无优先级反转，
/// 适合实时音频线程与主线程之间的短临界区同步。标记为 `@unchecked Sendable`，
/// 因为同步语义由内部锁保证，可安全跨线程持有。
final class LockedBox<Value>: @unchecked Sendable {
    private var value: Value
    private var lock = os_unfair_lock_s()

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return body(&value)
    }
}

/// 实时白噪音生成器。
///
/// 使用 `AVAudioEngine` + `AVAudioSourceNode` 在音频渲染线程里**逐帧算法生成**
/// 白噪声、粉噪声、棕噪声，可独立开关、调节音量并混合后输出。
///
/// ## 线程安全
/// 渲染回调运行在实时音频线程，主线程（ViewModel）会随时修改音量/开关。
/// 「控制量」放在 `LockedBox<ControlState>`（`os_unfair_lock`）里：主线程写入，
/// 音频线程在渲染开始时**只花一次短临界区拷贝快照**，随后整个帧循环在锁外
/// 用快照计算（见 issue #1215）。滤波器系数由音频线程独占（`FilterState`），
/// 跨帧持续，不参与加锁——把整段帧循环放在锁里会让主线程的音量调节
/// 等待一整次实时渲染。
///
/// ## macOS 说明
/// macOS 上 `AVAudioSession` 的 category/mode API 在 Swift 中不可用，故不做
/// session 配置——`AVAudioEngine` 在 macOS 上默认即可播放，并与其它 App 音频混音。
final class NoiseGenerator {
    /// 主线程与音频线程共享的控制量（锁保护）。
    private struct ControlState: Sendable {
        var whiteEnabled: Bool = false
        var pinkEnabled: Bool = false
        var brownEnabled: Bool = false
        var whiteVolume: Float = 0.5
        var pinkVolume: Float = 0.5
        var brownVolume: Float = 0.5
        var masterVolume: Float = 0.8
    }

    /// 滤波器系数：音频渲染线程独占，需跨帧持续，不加锁。
    /// `@unchecked Sendable` 仅为了让渲染闭包能捕获它；
    /// 实际访问只发生在串行的实时音频线程上。
    private final class FilterState: @unchecked Sendable {
        var pinkB0: Float = 0
        var pinkB1: Float = 0
        var pinkB2: Float = 0
        var pinkB3: Float = 0
        var pinkB4: Float = 0
        var pinkB5: Float = 0
        var pinkB6: Float = 0
        var brownLast: Float = 0
    }

    /// 输出格式：非交错 32-bit 浮点，44.1kHz，立体声。
    private let format: AVAudioFormat
    private let engine: AVAudioEngine
    private let sourceNode: AVAudioSourceNode
    private let state: LockedBox<ControlState>

    var isRunning: Bool { engine.isRunning }

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let state = LockedBox(ControlState())
        let filters = FilterState()
        self.format = format
        self.state = state
        self.engine = AVAudioEngine()

        // 仅捕获 Sendable 的 `state` 与音频线程独占的 `filters`，
        // 不捕获 self，满足 `@Sendable` 要求。
        self.sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            Self.render(into: UnsafeMutableAudioBufferListPointer(audioBufferList),
                        frameCount: frameCount,
                        state: state,
                        filters: filters)
            return noErr
        }
    }

    deinit {
        engine.stop()
    }

    // MARK: - Playback

    /// 启动引擎。
    func start() throws {
        if sourceNode.engine == nil {
            engine.attach(sourceNode)
            // 连接到主混音节点；主混音到输出由引擎自动处理。
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
    }

    // MARK: - Controls（主线程调用）

    func setEnabled(_ enabled: Bool, for track: NoiseTrack) {
        state.withLock { s in
            switch track {
            case .white: s.whiteEnabled = enabled
            case .pink: s.pinkEnabled = enabled
            case .brown: s.brownEnabled = enabled
            }
        }
    }

    func setVolume(_ volume: Float, for track: NoiseTrack) {
        let clamped = min(max(volume, 0), 1)
        state.withLock { s in
            switch track {
            case .white: s.whiteVolume = clamped
            case .pink: s.pinkVolume = clamped
            case .brown: s.brownVolume = clamped
            }
        }
    }

    func setMaster(_ volume: Float) {
        let clamped = min(max(volume, 0), 1)
        state.withLock { s in
            s.masterVolume = clamped
        }
    }

    // MARK: - Render

    /// 渲染回调：逐帧生成噪声样本并写入输出缓冲区。
    ///
    /// 采用 Paul Kellet 的粉噪声滤波器与积分式棕噪声算法：
    /// - 白噪声：均匀分布随机数，全频段等能量。
    /// - 粉噪声：对白噪声做多阶低通，每倍频能量恒定。
    /// - 棕噪声：对白噪声积分，能量集中在低频。
    private static func render(into buffers: UnsafeMutableAudioBufferListPointer,
                               frameCount: AVAudioFrameCount,
                               state: LockedBox<ControlState>,
                               filters: FilterState) {
        // 预先取出各声道缓冲区指针（标准格式为非交错）。
        var channels: [UnsafeMutablePointer<Float>] = []
        channels.reserveCapacity(buffers.count)
        for i in 0..<buffers.count {
            guard let data = buffers[i].mData else { continue }
            channels.append(data.assumingMemoryBound(to: Float.self))
        }

        // 归一化系数，使各噪声幅值接近 ±1。
        let pinkScale: Float = 0.18
        let brownScale: Float = 3.5

        // 锁内只拷贝一份控制量快照；整个帧循环在锁外执行，
        // 主线程的音量/开关更新不必等一整次实时渲染（见 issue #1215）。
        let controls = state.withLock { $0 }

        for frame in 0..<Int(frameCount) {
            let white = Float.random(in: -1...1)

            // Paul Kellet 粉噪声滤波器
            filters.pinkB0 = 0.99886 * filters.pinkB0 + white * 0.0555179
            filters.pinkB1 = 0.99332 * filters.pinkB1 + white * 0.0750759
            filters.pinkB2 = 0.96900 * filters.pinkB2 + white * 0.1538520
            filters.pinkB3 = 0.86650 * filters.pinkB3 + white * 0.3104856
            filters.pinkB4 = 0.55000 * filters.pinkB4 + white * 0.5329522
            filters.pinkB5 = -0.7616 * filters.pinkB5 - white * 0.0168980
            let pink = filters.pinkB0 + filters.pinkB1 + filters.pinkB2 + filters.pinkB3
                + filters.pinkB4 + filters.pinkB5 + filters.pinkB6 + white * 0.5362
            filters.pinkB6 = white * 0.115926

            // 积分式棕噪声
            filters.brownLast = (filters.brownLast + 0.02 * white) / 1.02

            var sample: Float = 0
            if controls.whiteEnabled { sample += white * controls.whiteVolume }
            if controls.pinkEnabled { sample += pink * pinkScale * controls.pinkVolume }
            if controls.brownEnabled { sample += filters.brownLast * brownScale * controls.brownVolume }
            sample *= controls.masterVolume

            // 软限幅，避免混合叠加时爆音
            if sample > 1 { sample = 1 } else if sample < -1 { sample = -1 }

            for channel in channels {
                channel[frame] = sample
            }
        }
    }
}
