import Foundation
import LumiPreviewKit

/// 极简帧循环：根据 `FrameStreamPolicy` 用 `Timer` 驱动 `renderer.snapshot()`。
///
/// 当前实现保留 Timer 驱动，但已经支持最小的交互节流：
/// 输入或启动时短暂进入 interactive，静止后自动回 idle。
/// idle 策略下只在 renderer dirty 后产帧，避免静止画面持续 snapshot。
/// 后续若动画同步精度不足，仍可把 interactive/animating 替换为 `CVDisplayLink`。
@MainActor
final class PreviewRenderLoop {

    // MARK: - 公开属性

    var onFrameReady: ((LumiPreviewFacade.IOSurfaceFrame) -> Void)?
    var onPolicyChanged: ((LumiPreviewFacade.FrameStreamPolicy) -> Void)?

    private(set) var policy: LumiPreviewFacade.FrameStreamPolicy = .stopped

    // MARK: - 私有属性

    private weak var renderer: PreviewRenderer?
    private var timer: Timer?
    private var idleWorkItem: DispatchWorkItem?
    private let interactiveCooldown: TimeInterval = 1.5

    // MARK: - 初始化

    init(renderer: PreviewRenderer) {
        self.renderer = renderer
    }

    // MARK: - 公开方法

    /// 切换策略。同策略重复调用是 noop。
    func setPolicy(_ new: LumiPreviewFacade.FrameStreamPolicy) {
        idleWorkItem?.cancel()
        idleWorkItem = nil
        applyPolicy(new)
    }

    /// 输入活动触发一段 interactive 帧流，静止后自动回到 idle。
    func noteInteractiveActivity() {
        renderer?.markDirty()
        applyPolicy(.interactive)
        scheduleIdleAfterCooldown()
    }

    /// 启动帧流时先推一段高频帧，让首帧和布局变化快速出现。
    func startInteractiveBurst() {
        noteInteractiveActivity()
    }

    private func applyPolicy(_ new: LumiPreviewFacade.FrameStreamPolicy) {
        guard new != policy else { return }
        policy = new
        onPolicyChanged?(new)

        timer?.invalidate()
        timer = nil

        switch new {
        case .stopped:
            return
        case .idle:
            startTimer(interval: 1.0)
        case .interactive, .animating:
            startTimer(interval: 1.0 / 60.0)
        }
    }

    func stop() {
        idleWorkItem?.cancel()
        idleWorkItem = nil
        setPolicy(.stopped)
    }

    // MARK: - 私有方法

    private func startTimer(interval: TimeInterval) {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let renderer else { return }
        let frame: LumiPreviewFacade.IOSurfaceFrame?
        switch policy {
        case .idle:
            frame = renderer.snapshotIfDirty()
        case .interactive, .animating:
            frame = renderer.snapshot()
        case .stopped:
            frame = nil
        }
        guard let frame else { return }
        onFrameReady?(frame)
    }

    private func scheduleIdleAfterCooldown() {
        idleWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.policy == .interactive else { return }
                self.applyPolicy(.idle)
                self.idleWorkItem = nil
            }
        }
        idleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interactiveCooldown, execute: workItem)
    }
}
