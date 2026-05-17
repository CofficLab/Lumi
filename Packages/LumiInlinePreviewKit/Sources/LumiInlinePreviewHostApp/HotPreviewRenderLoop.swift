import Foundation
import LumiInlinePreviewKit

/// 极简帧循环：根据 `FrameStreamPolicy` 用 `Timer` 驱动 `renderer.snapshot()`。
///
/// Phase 2 不做 dirty 检测、interactive cooldown 等高级策略，只把"按 fps 持续推帧"
/// 的最短链路打通。后续阶段会换成 `CVDisplayLink` + dirty 检测 + 自动节流。
@MainActor
final class HotPreviewRenderLoop {

    // MARK: - 公开属性

    var onFrameReady: ((LumiInlinePreviewFacade.IOSurfaceFrame) -> Void)?
    var onPolicyChanged: ((LumiInlinePreviewFacade.FrameStreamPolicy) -> Void)?

    private(set) var policy: LumiInlinePreviewFacade.FrameStreamPolicy = .stopped

    // MARK: - 私有属性

    private weak var renderer: HotPreviewRenderer?
    private var timer: Timer?

    // MARK: - 初始化

    init(renderer: HotPreviewRenderer) {
        self.renderer = renderer
    }

    // MARK: - 公开方法

    /// 切换策略。同策略重复调用是 noop。
    func setPolicy(_ new: LumiInlinePreviewFacade.FrameStreamPolicy) {
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
        guard let renderer, let frame = renderer.snapshot() else { return }
        onFrameReady?(frame)
    }
}
