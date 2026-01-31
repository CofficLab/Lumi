import AppKit
import MagicKit
import OSLog
import SwiftUI

/// macOS应用代理，处理应用级别的生命周期事件和系统集成
@MainActor
class MacAgent: NSObject, NSApplicationDelegate, SuperLog {
    static let emoji = "🍎"

    static let verbose = true

    /// 系统状态栏项
    private var statusItem: NSStatusItem?

    /// 插件提供者，用于获取插件菜单项
    private var pluginProvider: PluginProvider?

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
        // 初始化插件提供者
        pluginProvider = PluginProvider(autoDiscover: true)

        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 设置图标
        if let button = statusItem?.button {
            // 使用 SF Symbol 作为图标
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Lumi")
            button.image?.isTemplate = true  // 使用模板模式，图标会随系统主题变色
        }

        // 监听插件加载完成通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePluginsDidLoad),
            name: NSNotification.Name("PluginsDidLoad"),
            object: nil
        )
        
        // 先设置一个基础菜单（不含插件项）
        setupStatusBarMenu()
        
        if Self.verbose {
            os_log("\(self.t)状态栏已设置，等待插件加载...")
        }
    }

    /// 处理插件加载完成通知
    @objc private func handlePluginsDidLoad() {
        if Self.verbose {
            os_log("\(self.t)收到插件加载完成通知，刷新菜单...")
        }
        refreshStatusBarMenu()
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
    
    /// 刷新状态栏菜单（插件加载后调用）
    private func refreshStatusBarMenu() {
        setupStatusBarMenu()
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
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
        
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
