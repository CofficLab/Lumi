import AppKit
import MagicKit
import OSLog
import Sparkle
import SwiftUI


/// macOS应用代理，处理应用级别的生命周期事件和系统集成
@MainActor
class MacAgent: NSObject, NSApplicationDelegate, SuperLog {
    static let emoji = "🍎"

    static let verbose = true

    /// 插件提供者，用于获取插件菜单项
    private var pluginProvider: PluginProvider?
    
    /// Sparkle 更新控制器，提供应用自动更新功能
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用启动完成时的处理逻辑
        setupApplication()

        // 发送应用启动完成的通知
        NotificationCenter.postApplicationDidFinishLaunching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 应用即将终止时的清理逻辑
        cleanupApplication()

        // 发送应用即将终止的通知
        NotificationCenter.postApplicationWillTerminate()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // 应用变为活跃状态时的处理逻辑

        // 发送应用变为活跃状态的通知
        NotificationCenter.postApplicationDidBecomeActive()
    }

    func applicationDidResignActive(_ notification: Notification) {
        // 应用变为非活跃状态时的处理逻辑

        // 发送应用变为非活跃状态的通知
        NotificationCenter.postApplicationDidResignActive()
    }

    /// 设置应用相关配置
    private func setupApplication() {
        // 配置应用启动时的设置
        // 例如：设置窗口样式、注册全局快捷键等
        
        // 初始化插件提供者
        pluginProvider = PluginProvider(autoDiscover: true)
    }

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
        updaterController.checkForUpdates(nil)
    }

    /// 清理应用资源
    private func cleanupApplication() {
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
        
        // 执行应用退出前的清理工作
        // 例如：保存用户数据、断开连接等
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
