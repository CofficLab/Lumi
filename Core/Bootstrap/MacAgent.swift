import AppKit
import SwiftUI

/// macOS应用代理，处理应用级别的生命周期事件和系统集成
class MacAgent: NSObject, NSApplicationDelegate {
    /// 系统状态栏项
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用启动完成时的处理逻辑
        setupApplication()
        setupStatusBar()

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
    }

    /// 设置系统状态栏图标
    private func setupStatusBar() {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 设置图标
        if let button = statusItem?.button {
            // 使用 SF Symbol 作为图标
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Lumi")
            button.image?.isTemplate = true  // 使用模板模式，图标会随系统主题变色
        }

        // 设置点击菜单
        setupStatusBarMenu()
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

        menu.addItem(NSMenuItem.separator())

        // 退出应用
        menu.addItem(NSMenuItem(
            title: "退出",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu
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

    /// 清理应用资源
    private func cleanupApplication() {
        // 移除状态栏图标
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }

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
