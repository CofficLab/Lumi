import AppKit
import SuperLogKit
import SwiftUI
import os

/// 启动器悬浮面板（borderless + nonactivating，可跨 Space 显示）
final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 启动器窗口控制器：管理全局悬浮搜索窗口的显示 / 隐藏 / 定位
@MainActor
public final class LauncherWindowController: NSObject, SuperLog {
    public nonisolated static let emoji = "🪟"
    public nonisolated static let verbose: Bool = false

    public static let shared = LauncherWindowController()

    // MARK: - State

    private var panel: LauncherPanel?
    private let searchModel: LauncherSearchModel

    /// 面板宽度
    private let panelWidth: CGFloat = 680
    /// 面板高度（搜索框 + 结果区固定预留）
    private let panelHeight: CGFloat = 460

    // MARK: - Initialization

    private override init() {
        self.searchModel = LauncherSearchModel.shared
        super.init()
    }

    // MARK: - Toggle

    /// 切换显示 / 隐藏（热键触发）
    public func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Show / Hide

    public func show() {
        let panel = ensurePanel()
        positionPanel(panel)

        // 激活 app 使面板可接收键盘输入（nonactivating 面板本身不抢前台 app 焦点）
        NSApp.activate(ignoringOtherApps: true)
        searchModel.reset()
        panel.makeKeyAndOrderFront(nil)

        // 触发一次应用扫描（带 mtime 缓存，代价低）
        AppSearchService.shared.scanApplications()

        if Self.verbose {
            QuickLauncherPlugin.logger.info("\(self.t)启动器窗口已显示")
        }
    }

    public func hide() {
        panel?.orderOut(nil)
        searchModel.reset()
    }

    // MARK: - Panel Management

    private func ensurePanel() -> LauncherPanel {
        if let panel { return panel }

        let panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Lumi Launcher"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.delegate = self

        let hostingView = NSHostingView(rootView: LauncherView())
        hostingView.setFrameSize(NSSize(width: panelWidth, height: panelHeight))
        panel.contentView = hostingView

        self.panel = panel
        return panel
    }

    /// 屏幕上方约 25% 处水平居中
    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - panelWidth / 2
        let y = visibleFrame.maxY - visibleFrame.height * 0.25 - panelHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - NSWindowDelegate

extension LauncherWindowController: NSWindowDelegate {
    /// 失焦（点击别处 / 切换 app）自动隐藏
    public nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in
            // 短暂延迟，避免选中结果跳转目标窗口时立即隐藏导致动作丢失
            try? await Task.sleep(for: .milliseconds(120))
            LauncherWindowController.shared.hideIfNotKey()
        }
    }

    /// 按 Esc 关闭由 SwiftUI onKeyPress 处理
    public nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            LauncherWindowController.shared.hide()
        }
        return true
    }
}

extension LauncherWindowController {
    /// 仅当面板已不是 key window 时隐藏（避免误关）
    func hideIfNotKey() {
        guard let panel, panel.isVisible, panel != NSApp.keyWindow else { return }
        hide()
    }
}
