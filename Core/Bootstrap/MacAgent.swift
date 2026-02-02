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
    
    /// 系统状态栏项
    private var statusItem: NSStatusItem?
    
    /// 活跃的插件源集合（用于决定状态栏图标颜色）
    private var activeSources: Set<String> = []

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
        
        // 初始化插件提供者
        pluginProvider = PluginProvider(autoDiscover: true)
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
    
    /// 更新状态栏图标外观
    private func updateStatusBarIconAppearance() {
        guard let button = statusItem?.button else { return }
        
        // 每次都重新获取基础图标，确保状态一致
        guard let baseImage = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Lumi") else {
            return
        }
        
        if !activeSources.isEmpty {
            if Self.verbose {
                os_log("\(self.t)激活状态栏高亮，当前源: \(self.activeSources)")
            }
            
            // 使用手动着色方案，解决 contentTintColor 在部分系统/模式下失效变成黑色的问题
            let color = NSColor.controlAccentColor
            let coloredImage = tintedImage(baseImage, color: color)
            button.image = coloredImage
            
            // 清除 tintColor，因为我们已经把颜色“烤”进图片里了
            button.contentTintColor = nil
        } else {
            if Self.verbose {
                os_log("\(self.t)取消状态栏高亮")
            }
            
            // 恢复默认模板模式，跟随系统颜色（黑/白）
            baseImage.isTemplate = true
            button.image = baseImage
            button.contentTintColor = nil
        }
    }
    
    /// 辅助方法：创建指定颜色的图片
    /// 解决直接设置 contentTintColor 可能导致图标变黑的问题
    private func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let newImage = NSImage(size: image.size)
        newImage.lockFocus()
        
        // 1. 绘制原图
        image.draw(in: NSRect(origin: .zero, size: image.size))
        
        // 2. 设置颜色并混合
        // sourceAtop: 在原图不透明的地方绘制颜色
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        
        newImage.unlockFocus()
        
        // 关键：必须关闭模板模式，否则系统会忽略像素颜色
        newImage.isTemplate = false
        return newImage
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

    /// 检查更新
    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
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
