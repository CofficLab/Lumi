import AppKit
import MagicKit
import OSLog
import SwiftUI

/// 状态栏控制器，负责状态栏图标和菜单的管理
@MainActor
class StatusBarController: NSObject, SuperLog {
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

    /// 插件提供者，用于获取插件菜单项
    private weak var pluginProvider: PluginProvider?

    // MARK: - Initialization

    override init() {
        super.init()
        if Self.verbose {
            os_log("\(self.t)状态栏控制器已初始化")
        }
    }

    // MARK: - Public Methods

    /// 设置状态栏
    func setupStatusBar(pluginProvider: PluginProvider?) {
        self.pluginProvider = pluginProvider

        // 创建状态栏项，使用 squareLength 确保有足够的正方形空间
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        // 1. 初始化 SwiftUI 视图
        let iconView = StatusBarIconView(viewModel: iconViewModel)
        let hostingView = InteractiveHostingView(rootView: iconView)
        // 增加一点宽度，确保旋转时边角不被裁切
        hostingView.frame = NSRect(x: 0, y: 0, width: 22, height: 22)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.iconHostingView = hostingView

        // 2. 将 SwiftUI 视图添加到状态栏按钮中
        // 清除原有图片
        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)

        // 3. 设置布局约束，确保视图居中且尺寸合适
        NSLayoutConstraint.activate([
            hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            // 使用 20x20 的尺寸，留出一点安全边距（标准状态栏高度约 22pt）
            hostingView.widthAnchor.constraint(equalToConstant: 20),
            hostingView.heightAnchor.constraint(equalToConstant: 20),
        ])

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

        // 先设置一个基础菜单（不含插件项）
        setupStatusBarMenu()

        if Self.verbose {
            os_log("\(self.t)状态栏已设置，等待插件加载...")
        }
    }

    /// 刷新状态栏菜单（插件加载后调用）
    func refreshStatusBarMenu() {
        setupStatusBarMenu()
    }

    /// 清理状态栏资源
    func cleanup() {
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
            os_log("\(self.t)收到插件加载完成通知，刷新菜单...")
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

    /// 设置状态栏菜单
    private func setupStatusBarMenu() {
        let menu = NSMenu()

        // 显示主窗口
        menu.addItem(NSMenuItem(
            title: "打开 Lumi",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem(
            title: "检查更新",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())

        // 添加所有插件提供的菜单项
        if let provider = pluginProvider {
            let pluginMenuItems = provider.getStatusBarMenuItems()

            if Self.verbose {
                os_log("\(self.t)获取到 \(pluginMenuItems.count) 个插件菜单项")
            }

            if !pluginMenuItems.isEmpty {
                // 添加插件菜单项
                for item in pluginMenuItems {
                    menu.addItem(item)
                }

                menu.addItem(NSMenuItem.separator())
            }
        }

        // 退出应用
        menu.addItem(NSMenuItem(
            title: "退出",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    /// 显示主窗口
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// 退出应用
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    /// 检查更新
    @objc private func checkForUpdates() {
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
    }
}

// MARK: - Preview

#Preview("StatusBar") {
    StatusBarIconView(viewModel: StatusBarIconViewModel())
        .frame(width: 20, height: 20)
}
