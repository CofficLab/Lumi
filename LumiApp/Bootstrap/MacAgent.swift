import AppKit
import LibGit2Swift
import SwiftUI

/// macOS 应用代理，协调应用生命周期和各个控制器
///
/// MacAgent 是 Lumi 应用的 AppKit 代理，遵循 NSApplicationDelegate 协议。
/// 负责处理 macOS 应用生命周期的关键事件：
/// - 应用启动完成
/// - 应用即将终止
/// - 应用激活/失活
/// - 打开文件/文件夹（拖拽到 Dock 图标）
///
/// 同时管理以下控制器：
/// - MenuBarController: 菜单栏状态图标和弹窗
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
    nonisolated static let verbose: Bool = false
    // MARK: - Controllers

    /// 状态栏控制器
    ///
    /// 负责管理菜单栏图标、弹窗和状态显示。
    /// 在应用启动时初始化，应用终止时清理。
    private var statusBarController: MenuBarController?
    private var didPresentInitialMainWindow = false

    // MARK: - Application Lifecycle

    /// 启动早期配置：关闭 macOS 在退出时保存/恢复 NSWindow 几何与窗口集合的行为。
    ///
    /// 与主 `WindowGroup` 的 `.restorationBehavior(.disabled)` 配合，窗口数量与 ID 仅由
    /// `CoreWindowIDStore` 与核心窗口状态存储控制。
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Self.disableSystemWindowRestoration()
    }

    /// 应用启动完成
    ///
    /// 在应用完成所有初始化后调用。
    /// 执行以下操作：
    /// 1. 记录启动日志（如果 verbose 为 true）
    /// 2. 初始化各个控制器
    /// 3. 恢复保存的窗口状态
    /// 4. 发送应用启动完成通知
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.verbose {
            AppLogger.core.info("\(self.t)应用启动完成")
        }

        ensureMainWindowPresented()

        // 初始化 libgit2（必须在任何 Git 操作之前调用）
        LibGit2.initialize()

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
            AppLogger.core.info("\(self.t)应用即将终止")
        }

        cleanupApplication()

        // 清理 libgit2
        LibGit2.shutdown()

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
            AppLogger.core.info("\(self.t)应用变为活跃状态")
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
        NotificationCenter.postApplicationDidResignActive()
    }

    /// 当应用已运行且用户再次点击 Dock 图标时，确保没有可见窗口的场景能恢复主窗口。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    // MARK: - Dock Menu

    /// 提供 Dock 右键菜单
    ///
    /// 当用户右键点击 Dock 图标时显示的菜单。
    /// 添加"新建窗口"选项。
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let newItem = NSMenuItem(
            title: "新建窗口",
            action: #selector(openNewWindowFromDock),
            keyEquivalent: "n"
        )
        newItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(newItem)
        return menu
    }

    /// 从 Dock 菜单打开新窗口
    @objc private func openNewWindowFromDock() {
        NotificationCenter.postOpenWindowWithRoute(route: LumiWindowRoute())
    }

    // MARK: - Open Files/Folders

    /// 处理打开文件/文件夹请求
    ///
    /// 当用户拖拽文件夹到 Dock 图标，或通过命令行参数打开文件时调用。
    /// 对于文件夹，会在新窗口中打开作为项目。
    /// 对于文件，会尝试在当前活跃窗口的编辑器中打开。
    ///
    /// - Parameter urls: 要打开的文件/文件夹 URL 列表
    func application(_ application: NSApplication, open urls: [URL]) {
        if Self.verbose {
            AppLogger.core.info("\(self.t)📂 收到打开请求: \(urls.map(\.lastPathComponent))")
        }

        for url in urls {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDirectory {
                // 文件夹：在新窗口中打开作为项目
                openProjectInNewWindow(path: url.path)
            } else {
                // 文件：在当前活跃窗口的编辑器中打开
                openFileInActiveWindow(url: url)
            }
        }
    }

    /// 在新窗口中打开项目
    ///
    /// - Parameter path: 项目路径
    private func openProjectInNewWindow(path: String) {
        // 检查是否已经有窗口打开了这个项目
        if let existingWindowId = RootContainer.shared.windowManagerVM.findWindow(withProject: path) {
            // 聚焦到已有窗口
            RootContainer.shared.windowManagerVM.activateWindow(existingWindowId)
            if Self.verbose {
                AppLogger.core.info("\(self.t)📂 项目已在窗口 \(existingWindowId.uuidString.prefix(8)) 中打开，聚焦该窗口")
            }
            return
        }

        // 创建新窗口打开项目
        let route = LumiWindowRoute(projectPath: path)
        NotificationCenter.postOpenWindowWithRoute(route: route)

        if Self.verbose {
            AppLogger.core.info("\(self.t)📂 在新窗口中打开项目: \(path)")
        }
    }

    private func ensureMainWindowPresented() {
        if RootContainer.shared.windowManagerVM.activatePreferredWindow() {
            didPresentInitialMainWindow = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            if RootContainer.shared.windowManagerVM.activatePreferredWindow() {
                self.didPresentInitialMainWindow = true
                return
            }
            NotificationCenter.postOpenWindowWithRoute(route: CoreWindowIDStore.consumeNextWindowRoute())
            self.didPresentInitialMainWindow = true
        }
    }

    /// 在当前活跃窗口的编辑器中打开文件
    ///
    /// - Parameter url: 文件 URL
    private func openFileInActiveWindow(url: URL) {
        let windowManager = RootContainer.shared.windowManagerVM
        if windowManager.activeWindowId == nil {
            _ = windowManager.activatePreferredWindow()
        }

        guard let windowId = windowManager.activeWindowId else {
            AppLogger.core.warning("\(self.t)无法打开文件，当前没有活跃窗口: \(url.path, privacy: .public)")
            return
        }

        // 通知活跃窗口打开文件
        NotificationCenter.postOpenFileInEditor(url: url, windowId: windowId)

        if Self.verbose {
            AppLogger.core.info("\(self.t)📄 在编辑器中打开文件: \(url.lastPathComponent)")
        }
    }

    // MARK: - Setup

    /// 设置各个控制器
    ///
    /// 初始化所有应用级别的控制器。
    /// 当前包括：
    /// - MenuBarController: 菜单栏管理
    private func setupControllers() {
        // 初始化菜单栏控制器
        statusBarController = MenuBarController()
        statusBarController?.setupMenuBar(pluginProvider: AppPluginVM.shared)
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

    static func disableSystemWindowRestoration(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        libraryDirectory: URL? = nil
    ) {
        defaults.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        defaults.set(true, forKey: "ApplePersistenceIgnoreState")

        guard let bundleIdentifier,
              let savedStateURL = savedApplicationStateURL(
                bundleIdentifier: bundleIdentifier,
                libraryDirectory: libraryDirectory
              ) else { return }

        try? fileManager.removeItem(at: savedStateURL)
    }

    static func savedApplicationStateURL(
        bundleIdentifier: String,
        libraryDirectory: URL? = nil
    ) -> URL? {
        let libraryURL = libraryDirectory
            ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first

        return libraryURL?
            .appendingPathComponent("Saved Application State", isDirectory: true)
            .appendingPathComponent("\(bundleIdentifier).savedState", isDirectory: true)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
