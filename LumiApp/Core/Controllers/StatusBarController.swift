import AppKit
import MagicKit
import SwiftUI

/// 状态栏控制器
///
/// 负责管理 macOS 菜单栏（状态栏）图标和弹出窗口。
///
/// ## 功能概述
///
/// - **图标管理**: 根据应用状态显示不同样式的状态栏图标
/// - **弹窗控制**: 点击图标显示/隐藏弹出窗口
/// - **插件集成**: 集成各插件提供的状态栏内容视图和弹窗视图
/// - **事件处理**: 处理应用失去焦点、窗口变化等事件
///
/// ## 视图结构
///
/// ```text
/// 状态栏图标
///     │
///     └── 点击 ──→ 弹出窗口 (NSPopover)
///                     │
///                     ├── 插件提供的弹窗视图 (getStatusBarPopupViews)
///                     ├── 显示主窗口按钮
///                     ├── 检查更新按钮
///                     └── 退出按钮
/// ```
@MainActor
class StatusBarController: NSObject, SuperLog, NSPopoverDelegate {
    /// 日志标识符
    nonisolated static let emoji = "📊"
    
    /// 是否启用详细日志
    static let verbose = false

    // MARK: - Properties

    /// 系统状态栏项
    ///
    /// NSStatusItem 代表菜单栏上的一个图标位。
    /// 可以包含自定义视图来显示动态内容。
    private var statusItem: NSStatusItem?

    /// 活跃的插件源集合
    ///
    /// 用于决定状态栏图标颜色。
    /// 当有活跃的插件（如正在下载、正在监控）时，
    /// 图标会显示为不同样式（如带颜色点）。
    private var activeSources: Set<String> = []

    /// 状态栏图标视图模型
    ///
    /// 管理图标的状态和内容视图。
    /// 使用 MVVM 模式管理 SwiftUI 视图的数据。
    private var iconViewModel = StatusBarIconVM()
    
    /// 状态栏图标的主机视图
    ///
    /// 将 SwiftUI 视图嵌入 AppKit 的 NSStatusItem。
    private var iconHostingView: InteractiveHostingView<StatusBarIconView>?

    /// 弹出窗口
    ///
    /// 点击状态栏图标时显示的弹窗。
    /// 使用 NSPopover 实现，行为为 transient（点击外部自动关闭）。
    private var popover: NSPopover?

    /// 插件 VM弱引用
    ///
    /// 弱引用避免循环引用。
    /// 用于获取插件提供的状态栏相关视图。
    private weak var pluginProvider: PluginVM?

    // MARK: - Public Methods

    /// 设置状态栏
    ///
    /// 初始化状态栏图标和所有必要的监听器。
    /// 此方法应在应用启动后调用。
    ///
    /// - Parameter pluginProvider: 插件 VM实例
    func setupStatusBar(pluginProvider: PluginVM?) {
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
        // 清除原有图片（默认的 SF Symbol 会被移除）
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)

        // 3. 设置布局约束，让视图根据内容自动确定宽度
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            // 固定高度为状态栏标准高度 (20pt)
            hostingView.heightAnchor.constraint(equalToConstant: 20),
        ])

        // 4. 设置点击动作
        button.action = #selector(statusBarButtonClicked)
        button.target = self

        // 5. 添加通知监听器
        setupNotificationObservers()

        // 6. 如果插件已经加载，立即更新状态栏内容
        if pluginProvider?.isLoaded == true {
            if Self.verbose {
                AppLogger.core.info("\(self.t)插件已加载，立即更新状态栏内容视图")
            }
            updateStatusBarContentViews()
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)状态栏已设置")
        }
    }

    /// 设置通知观察者
    ///
    /// 集中管理所有通知监听器，便于清理。
    private func setupNotificationObservers() {
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
    }

    /// 刷新状态栏弹窗
    ///
    /// 在插件加载完成后调用，用于：
    /// 1. 关闭当前显示的弹窗
    /// 2. 更新插件提供的内容视图
    func refreshStatusBarMenu() {
        // 如果弹窗正在显示，关闭它以便重新加载
        closePopover()

        // 更新状态栏内容视图
        updateStatusBarContentViews()
    }

    /// 更新状态栏内容视图
    ///
    /// 从插件 VM获取所有插件提供的状态栏内容视图，
    /// 并更新到图标视图模型中。
    private func updateStatusBarContentViews() {
        let views = pluginProvider?.getStatusBarContentViews() ?? []
        iconViewModel.contentViews = views

        if Self.verbose {
            AppLogger.core.info("\(self.t)更新状态栏内容视图: \(views.count) 个")
        }
    }

    /// 清理状态栏资源
    ///
    /// 在应用终止时调用，执行清理操作：
    /// 1. 关闭弹窗
    /// 2. 移除通知观察者
    /// 3. 移除状态栏图标
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
            AppLogger.core.info("\(self.t)状态栏已清理")
        }
    }

    // MARK: - Notification Handlers

    /// 处理插件加载完成通知
    ///
    /// 当所有插件加载完成后，更新状态栏内容。
    @objc private func handlePluginsDidLoad() {
        if Self.verbose {
            AppLogger.core.info("\(self.t)收到插件加载完成通知")
        }
        refreshStatusBarMenu()
    }

    /// 处理状态栏外观更新请求
    ///
    /// 当某个插件源需要更新图标状态时调用。
    /// 例如：下载插件开始下载时请求显示活跃状态。
    ///
    /// - Parameter notification: 通知对象，包含 isActive 和 source 信息
    @objc private func handleStatusBarAppearanceUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isActive = userInfo["isActive"] as? Bool,
              let source = userInfo["source"] as? String else {
            return
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)收到状态栏更新请求: source=\(source), isActive=\(isActive)")
        }

        if isActive {
            activeSources.insert(source)
        } else {
            activeSources.remove(source)
        }

        updateStatusBarIconAppearance()
    }

    /// 处理应用失去焦点
    ///
    /// 当用户切换到其他应用时，关闭弹窗。
    @objc private func handleApplicationResignedActive() {
        closePopover()
    }

    /// 处理窗口焦点变化
    ///
    /// 当新的窗口获得焦点时：
    /// - 如果弹窗正在显示且新焦点窗口不是弹窗，则关闭弹窗
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
    ///
    /// 切换弹窗的显示/隐藏状态。
    @objc private func statusBarButtonClicked() {
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    /// 显示弹窗
    ///
    /// 创建（如果不存在）并显示弹出窗口。
    private func showPopover() {
        guard let button = statusItem?.button else { return }

        // 如果弹窗不存在，创建它
        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 280, height: 400)
            // transient: 点击弹窗外部区域会自动关闭
            popover?.behavior = .transient
            // 启用动画效果
            popover?.animates = true
            popover?.delegate = self
            popover?.contentViewController = NSHostingController(
                rootView: createPopupView()
            )
        }

        // 显示弹窗，锚定在按钮底部
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // 添加全局事件监听器，检测点击外部区域
        addGlobalEventMonitor()

        if Self.verbose {
            AppLogger.core.info("\(self.t)显示弹窗")
        }
    }

    /// 全局事件监听器
    ///
    /// 监听全局鼠标点击事件，用于检测用户点击其他应用。
    private var eventMonitor: Any?

    /// 添加全局事件监听
    ///
    /// 监听全局点击事件，当用户点击其他应用时关闭弹窗。
    private func addGlobalEventMonitor() {
        // 先移除旧的监听器
        removeGlobalEventMonitor()

        // 监听全局鼠标点击事件
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

    /// 弹窗是否应该关闭
    ///
    /// - Parameter popover: 弹窗实例
    /// - Returns: 是否允许关闭
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if Self.verbose {
            AppLogger.core.info("\(self.t)Popover 应该关闭")
        }
        return true
    }

    /// 弹窗已关闭
    ///
    /// 清理全局事件监听器。
    func popoverDidClose(_ notification: Notification) {
        if Self.verbose {
            AppLogger.core.info("\(self.t)Popover 已关闭")
        }
        removeGlobalEventMonitor()
    }

    /// 关闭弹窗
    private func closePopover() {
        popover?.performClose(nil)
        removeGlobalEventMonitor()
    }

    /// 创建弹窗视图
    ///
    /// 组合所有插件提供的弹窗视图和默认操作按钮。
    ///
    /// - Returns: 完整的弹窗视图
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
    ///
    /// 根据 activeSources 集合更新图标显示状态。
    /// 有活跃源时显示特殊样式（如带颜色的点）。
    private func updateStatusBarIconAppearance() {
        let isActive = !self.activeSources.isEmpty

        if Self.verbose {
            AppLogger.core.info("\(self.t)更新图标状态: isActive=\(isActive), sources=\(self.activeSources)")
        }

        // 更新 ViewModel，触发 SwiftUI 刷新
        iconViewModel.isActive = isActive
        iconViewModel.activeSources = self.activeSources
    }

    // MARK: - Menu Actions

    /// 显示主窗口
    ///
    /// 激活应用并显示主窗口。
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
    ///
    /// 发送检查更新通知，由 App 层级处理。
    private func checkForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }
}

// MARK: - Preview

#Preview("StatusBar") {
    StatusBarIconView(viewModel: StatusBarIconVM())
        .frame(width: 20, height: 20)
}
