import AppKit
import MagicKit
import OSLog
import SwiftUI

/// macOS 应用代理，协调应用生命周期和各个控制器
@MainActor
class MacAgent: NSObject, NSApplicationDelegate, SuperLog {
    nonisolated static let emoji = "🍎"
    static let verbose = false

    // MARK: - Controllers

    /// 状态栏控制器
    private var statusBarController: StatusBarController?

    /// 更新控制器
    private var updateController: UpdateController?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用启动完成")
        }

        setupControllers()

        // 发送应用启动完成的通知
        NotificationCenter.postApplicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用即将终止")
        }

        cleanupApplication()

        // 发送应用即将终止的通知
        NotificationCenter.postApplicationWillTerminate()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用变为活跃状态")
        }

        // 发送应用变为活跃状态的通知
        NotificationCenter.postApplicationDidBecomeActive()
    }

    func applicationDidResignActive(_ notification: Notification) {
        if Self.verbose {
            os_log("\(self.t)应用变为非活跃状态")
        }

        // 发送应用变为非活跃状态的通知
        NotificationCenter.postApplicationDidResignActive()
    }

    // MARK: - Setup

    /// 设置各个控制器
    private func setupControllers() {
        // 初始化更新控制器
        updateController = UpdateController()

        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        statusBarController?.setupStatusBar(pluginProvider: PluginProvider.shared)
    }

    // MARK: - Cleanup

    /// 清理应用资源
    private func cleanupApplication() {
        // 清理各个控制器
        statusBarController?.cleanup()

        // 移除通知观察者
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
