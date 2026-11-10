import AppKit
import SwiftUI

/// 遮罩窗口的最小抽象。
///
/// 抽出接口有两个原因：
///
/// 1. **可测**：真实 `NSWindow` 在单元测试进程里既难创建也不好断言，
///    而「遮罩永久滞留屏幕」恰恰是一个**时序 bug**——必须能验证
///    「淡出回调必定被执行」。因此控制器的时序逻辑必须能在无窗口环境下被验证。
/// 2. **平台细节隔离**：AppKit 的窗口创建、动画与事件处理集中在实现里，
///    控制器只关心「显示 / 隐藏 / 关闭 / 设置不透明度」。
@MainActor
public protocol ReminderOverlayWindowing: AnyObject {
    /// 遮罩当前是否仍在展示。
    var isVisible: Bool { get }

    /// 设置不透明度。
    ///
    /// - Parameters:
    ///   - alpha: 目标不透明度（0 为完全透明）。
    ///   - animated: 是否使用动画过渡。
    ///   - duration: 动画时长（秒）。
    ///   - completion: 动画结束（或立即应用）后的回调。
    func setAlpha(
        _ alpha: CGFloat,
        animated: Bool,
        duration: TimeInterval,
        completion: (() -> Void)?
    )

    /// 将遮罩置于最前。
    func show()

    /// 将遮罩移出屏幕。
    func hide()

    /// 彻底释放遮罩窗口。
    func tearDown()
}

/// 基于 `NSPanel` 的真实遮罩窗口。
///
/// 关键配置对齐项目既有的截图遮罩（`ChatScreenshotOverlayWindow`）：
/// - `borderless` + 透明背景，只显示 SwiftUI 绘制的内容；
/// - `collectionBehavior` 跨 Space、随全屏应用显现、不被 Dock 触发隐藏；
/// - `ignoresMouseEvents = false`——遮罩必须能接收点击，
///   否则用户被困在遮罩里时连关闭都做不到。
///
/// 之所以用 `NSPanel` 而不是普通 `NSWindow`：无边框 `NSWindow` 默认
/// `canBecomeKey == false`，收不到 Esc 键；`NSPanel` 可以成为 key window，
/// 用户才能用 Esc 关闭遮罩（否则一旦自动淡出失效，用户会被困在全屏遮罩里）。
final class ReminderOverlayPanelWindow: ReminderOverlayWindowing {
    private let panel: ReminderOverlayPanel
    private var visible = false

    init(
        screen: NSScreen,
        content: @escaping () -> AnyView,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        // 用 frame 而非 visibleFrame：遮罩应覆盖整块屏幕，包括 Dock 与菜单栏区域。
        panel = ReminderOverlayPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // 点击任意处关闭：用户被困住时，屏幕上任何一次点击都应该能解脱。
        let rootView = content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
            .onExitCommand { onDismiss() }

        panel.contentView = NSHostingView(rootView: rootView)
    }

    var isVisible: Bool { visible }

    func setAlpha(
        _ alpha: CGFloat,
        animated: Bool,
        duration: TimeInterval,
        completion: (() -> Void)?
    ) {
        guard animated else {
            panel.alphaValue = alpha
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.completionHandler = completion
            panel.animator().alphaValue = alpha
        }
    }

    func show() {
        // 激活宿主 App，让 Esc 能送达本面板（key 事件只发给当前活跃 App）。
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        visible = true
    }

    func hide() {
        panel.orderOut(nil)
        visible = false
    }

    func tearDown() {
        panel.close()
    }
}

/// 允许成为 key window 的无边框遮罩面板，保证 Esc 能送达。
final class ReminderOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
