import AppKit
import MagicKit
import OSLog
import SwiftUI

/// 状态栏控制器，负责状态栏图标和弹窗的管理
@MainActor
class StatusBarController: NSObject, SuperLog, NSPopoverDelegate {
    nonisolated static let emoji = "📊"
    static let verbose = true

    // MARK: - Properties

    /// 系统状态栏项
    private var statusItem: NSStatusItem?

    /// 活跃的插件源集合（用于决定状态栏图标颜色）
    private var activeSources: Set<String> = []

    /// 状态栏图标相关
    private var iconViewModel = StatusBarIconViewModel()
    private var iconHostingView: InteractiveHostingView<StatusBarIconView>?

    /// 弹窗
    private var popover: NSPopover?

    /// 插件提供者，用于获取插件菜单项
    private weak var pluginProvider: PluginProvider?

    // MARK: - Public Methods

    /// 设置状态栏
    func setupStatusBar(pluginProvider: PluginProvider?) {
        self.pluginProvider = pluginProvider

        // 创建状态栏项，使用 variableLength 以便根据内容动态调整宽度
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // 1. 初始化 SwiftUI 视图
        let iconView = StatusBarIconView(viewModel: iconViewModel)
        let hostingView = InteractiveHostingView(rootView: iconView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.iconHostingView = hostingView

        // 2. 将 SwiftUI 视图添加到状态栏按钮中
        // 清除原有图片
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)

        // 3. 设置布局约束，让视图根据内容自动确定宽度
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            // 固定高度为状态栏标准高度
            hostingView.heightAnchor.constraint(equalToConstant: 20),
        ])

        // 4. 设置点击动作
        button.action = #selector(statusBarButtonClicked)
        button.target = self

        // 监听插件加载完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePluginsDidLoad),
            name: NSNotification.Name("PluginsDidLoad"),
            object: nil
        )

        // 监听状态栏外观更新请求
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStatusBarAppearanceUpdate(_:)),
            name: .requestStatusBarAppearanceUpdate,
            object: nil
        )

        // 监听应用失去焦点，关闭弹窗
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationResignedActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // 监听窗口焦点变化，关闭弹窗
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowChanged),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        // 如果插件已经加载（通知可能在监听器设置之前发送），立即更新
        if pluginProvider?.isLoaded == true {
            if Self.verbose {
                os_log("\(self.t)插件已加载，立即更新状态栏内容视图")
            }
            updateStatusBarContentViews()
        }

        if Self.verbose {
            os_log("\(self.t)状态栏已设置")
        }
    }

    /// 刷新状态栏弹窗（插件加载后调用）
    func refreshStatusBarMenu() {
        // 如果弹窗正在显示，关闭它以便重新加载
        closePopover()

        // 更新状态栏内容视图
        updateStatusBarContentViews()
    }

    /// 更新状态栏内容视图
    private func updateStatusBarContentViews() {
        let views = pluginProvider?.getStatusBarContentViews() ?? []
        iconViewModel.contentViews = views

        if Self.verbose {
            os_log("\(self.t)更新状态栏内容视图: \(views.count) 个")
        }
    }

    /// 清理状态栏资源
    func cleanup() {
        closePopover()

        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)

        // 移除状态栏图标
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }

        if Self.verbose {
            os_log("\(self.t)状态栏已清理")
        }
    }

    // MARK: - Notification Handlers

    /// 处理插件加载完成通知
    @objc private func handlePluginsDidLoad() {
        if Self.verbose {
            os_log("\(self.t)收到插件加载完成通知")
        }
        refreshStatusBarMenu()
    }

    /// 处理状态栏外观更新请求
    @objc private func handleStatusBarAppearanceUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isActive = userInfo["isActive"] as? Bool,
              let source = userInfo["source"] as? String else {
            return
        }

        if Self.verbose {
            os_log("\(self.t)收到状态栏更新请求: source=\(source), isActive=\(isActive)")
        }

        if isActive {
            activeSources.insert(source)
        } else {
            activeSources.remove(source)
        }

        updateStatusBarIconAppearance()
    }

    /// 处理应用失去焦点
    @objc private func handleApplicationResignedActive() {
        closePopover()
    }

    /// 处理窗口焦点变化
    @objc private func handleWindowChanged(_ notification: Notification) {
        guard let popover = popover, popover.isShown,
              let popoverWindow = popover.contentViewController?.view.window else { return }

        // 如果成为keyWindow的不是popover窗口，关闭popover
        if let keyWindow = NSApp.keyWindow, keyWindow != popoverWindow {
            closePopover()
        }
    }

    // MARK: - Status Bar Actions

    /// 状态栏按钮点击事件
    @objc private func statusBarButtonClicked() {
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    /// 显示弹窗
    private func showPopover() {
        guard let button = statusItem?.button else { return }

        // 如果弹窗不存在，创建它
        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 280, height: 400)
            popover?.behavior = .transient
            popover?.animates = true
            popover?.delegate = self
            popover?.contentViewController = NSHostingController(
                rootView: createPopupView()
            )
        }

        // 显示弹窗
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 添加全局事件监听器，检测点击外部区域
        addGlobalEventMonitor()

        if Self.verbose {
            os_log("\(self.t)显示弹窗")
        }
    }

    /// 全局事件监听器
    private var eventMonitor: Any?

    /// 添加全局事件监听
    private func addGlobalEventMonitor() {
        // 先移除旧的监听器
        removeGlobalEventMonitor()

        // 只监听全局点击事件（用于检测点击其他应用）
        // .transient 行为已经可以处理应用内的点击外部关闭
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }

        self.eventMonitor = globalMonitor
    }

    /// 移除全局事件监听
    private func removeGlobalEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if Self.verbose {
            os_log("\(self.t)Popover 应该关闭")
        }
        return true
    }

    func popoverDidClose(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)Popover 已关闭")
        }
    }

    /// 关闭弹窗
    private func closePopover() {
        popover?.performClose(nil)
        removeGlobalEventMonitor()
    }

    /// 创建弹窗视图
    private func createPopupView() -> StatusBarPopupView {
        let pluginViews = pluginProvider?.getStatusBarPopupViews() ?? []

        return StatusBarPopupView(
            pluginPopupViews: pluginViews,
            onShowMainWindow: { [weak self] in
                self?.showMainWindow()
                self?.closePopover()
            },
            onCheckForUpdates: { [weak self] in
                self?.checkForUpdates()
                self?.closePopover()
            },
            onQuit: { [weak self] in
                self?.quitApplication()
            }
        )
    }

    // MARK: - Private Methods

    /// 更新状态栏图标外观
    private func updateStatusBarIconAppearance() {
        let isActive = !self.activeSources.isEmpty

        if Self.verbose {
            os_log("\(self.t)更新图标状态: isActive=\(isActive), sources=\(self.activeSources)")
        }

        // 更新 ViewModel，触发 SwiftUI 刷新
        iconViewModel.isActive = isActive
        iconViewModel.activeSources = self.activeSources
    }

    // MARK: - Menu Actions

    /// 显示主窗口
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// 退出应用
    private func quitApplication() {
        NSApp.terminate(nil)
    }

    /// 检查更新
    private func checkForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }
}

// MARK: - Preview

#Preview("StatusBar") {
    StatusBarIconView(viewModel: StatusBarIconViewModel())
        .frame(width: 20, height: 20)
}
