import AppKit
import SwiftUI

/// 卸载流程的独立无边框浮层窗口控制器。
///
/// 卸载会清除 Lumi 自身数据，设置主窗口内容在卸载过程中可能失效，因此
/// 「卸载中 / 卸载完成 / 卸载失败」三态在与主窗口解耦的独立浮层中展示，
/// 由该控制器管理浮层的创建、内容刷新与关闭。
@MainActor
final class UninstallOverlayWindowController {
    static let shared = UninstallOverlayWindowController()

    private var panel: UninstallOverlayPanel?
    private var hostingView: NSHostingView<UninstallOverlayView>?
    private var onExit: (@MainActor () -> Void)?
    private var onClose: (@MainActor () -> Void)?

    private init() {}

    /// 展示卸载浮层；浮层已存在时刷新内容并前置到最上层。
    func show(
        phase: UninstallOverlayPhase,
        onExit: @escaping @MainActor () -> Void,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.onExit = onExit
        self.onClose = onClose

        let rootView = UninstallOverlayView(phase: phase, onExit: onExit, onClose: onClose)
        if let panel, let hostingView {
            hostingView.rootView = rootView
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            return
        }

        let panel = UninstallOverlayPanel(
            contentRect: UninstallOverlayPanel.contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // 阴影由 SwiftUI 视图绘制
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = panel.contentView?.bounds ?? UninstallOverlayPanel.contentRect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    /// 刷新浮层阶段（如 running → succeeded / failed）。
    func update(phase: UninstallOverlayPhase) {
        guard let panel, let hostingView, let onExit, let onClose else { return }
        hostingView.rootView = UninstallOverlayView(phase: phase, onExit: onExit, onClose: onClose)
        panel.orderFrontRegardless()
    }

    /// 关闭并释放浮层。
    func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        hostingView = nil
        onExit = nil
        onClose = nil
    }
}

/// 允许成为 key window 的无边框浮层，保证「关闭」等按钮可点击。
final class UninstallOverlayPanel: NSPanel {
    static let contentRect = NSRect(x: 0, y: 0, width: 420, height: 380)

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
