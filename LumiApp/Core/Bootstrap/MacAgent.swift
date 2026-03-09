import AppKit
import MagicKit
import OSLog
import SwiftUI

/// macOS 应用代理，协调应用生命周期和各个控制器
///
/// MacAgent 是 Lumi 应用的 AppKit 代理，遵循 NSApplicationDelegate 协议。
/// 负责处理 macOS 应用生命周期的关键事件：
/// - 应用启动完成
/// - 应用即将终止
/// - 应用激活/失活
///
/// 同时管理以下控制器：
/// - StatusBarController: 菜单栏状态图标和弹窗
///
/// ## 生命周期顺序
///
/// ```text
/// applicationDidFinishLaunching()
///     ↓
/// [用户使用应用]
///     ↓
/// applicationDidResignActive() / applicationDidBecomeActive()
///     ↓
/// applicationWillTerminate()
/// ```
@MainActor
class MacAgent: NSObject, NSApplicationDelegate, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "🍎"
    
    /// 是否启用详细日志
    static let verbose = false

    // MARK: - Controllers

    /// 状态栏控制器
    ///
    /// 负责管理菜单栏图标、弹窗和状态显示。
    /// 在应用启动时初始化，应用终止时清理。
    private var statusBarController: StatusBarController?

    // MARK: - Application Lifecycle

    /// 应用启动完成
    ///
    /// 在应用完成所有初始化后调用。
    /// 执行以下操作：
    /// 1. 记录启动日志（如果 verbose 为 true）
    /// 2. 初始化各个控制器
    /// 3. 发送应用启动完成通知
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用启动完成")
        }

        setupControllers()

        // 发送应用启动完成的通知
        // 让其他组件知道应用已准备好接受交互
        NotificationCenter.postApplicationDidFinishLaunching()
    }

    /// 应用即将终止
    ///
    /// 在应用退出前调用。
    /// 执行清理操作：
    /// 1. 记录终止日志
    /// 2. 清理各个控制器
    /// 3. 发送终止通知
    func applicationWillTerminate(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用即将终止")
        }

        cleanupApplication()

        // 发送应用即将终止的通知
        // 让插件和组件保存状态、断开连接
        NotificationCenter.postApplicationWillTerminate()
    }

    /// 应用变为活跃状态
    ///
    /// 当应用从非活跃变为活跃时调用。
    /// 可能发生在：
    /// - 用户点击应用窗口
    /// - 从其他应用切换回来
    func applicationDidBecomeActive(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用变为活跃状态")
        }

        // 发送应用变为活跃状态的通知
        // 让插件可以刷新数据或 UI
        NotificationCenter.postApplicationDidBecomeActive()
    }

    /// 应用变为非活跃状态
    ///
    /// 当应用从活跃变为非活跃时调用。
    /// 可能发生在：
    /// - 用户切换到其他应用
    /// - 应用窗口被最小化
    func applicationDidResignActive(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用变为非活跃状态")
        }

        // 发送应用变为非活跃状态的通知
        // 让插件可以暂停某些活动
        NotificationCenter.postApplicationDidResignActive()
    }

    // MARK: - Dock Menu

    /// 返回 Dock 右键菜单
    ///
    /// 当用户在 Dock 栏图标上右键点击时显示此菜单
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        // 新建窗口菜单项
        let newWindowItem = NSMenuItem(
            title: "新建窗口",
            action: #selector(dockNewWindow),
            keyEquivalent: ""
        )
        newWindowItem.target = self
        menu.addItem(newWindowItem)

        return menu
    }

    /// Dock 菜单：新建窗口
    @objc private func dockNewWindow() {
        WindowManager.shared.openNewWindow()
    }

    // MARK: - Setup

    /// 设置各个控制器
    ///
    /// 初始化所有应用级别的控制器。
    /// 当前包括：
    /// - StatusBarController: 状态栏管理
    private func setupControllers() {
        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        statusBarController?.setupStatusBar(pluginProvider: PluginProvider.shared)
    }

    // MARK: - Cleanup

    /// 清理应用资源
    ///
    /// 在应用终止前调用，执行清理操作：
    /// 1. 清理各个控制器
    /// 2. 移除通知观察者
    private func cleanupApplication() {
        // 清理各个控制器
        statusBarController?.cleanup()

        // 移除通知观察者
        // 防止在应用终止后仍收到通知
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}