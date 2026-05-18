import AppKit
import LibGit2Swift
import MagicKit
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

    // MARK: - Application Lifecycle

    /// 应用启动完成
    ///
    /// 在应用完成所有初始化后调用。
    /// 执行以下操作：
    /// 1. 记录启动日志（如果 verbose 为 true）
    /// 2. 初始化各个控制器
    /// 3. 恢复保存的窗口状态
    /// 4. 发送应用启动完成通知
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 启动磁盘日志收集
        FileLogCoordinator.shared.start()

        if Self.verbose {
            AppLogger.core.info("\(self.t)应用启动完成")
        }

        // 初始化 libgit2（必须在任何 Git 操作之前调用）
        LibGit2.initialize()

        setupControllers()

        // 启动自动化 HTTP 服务器（用于自动化测试）
        AutomationServer.shared.start()

        // 启动自动化控制器（用于路由和处理自动化动作）
        AutomationController.shared.start()

        // 恢复保存的窗口状态（延迟执行，确保 SwiftUI 视图已准备好）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.restoreSavedWindowStates()
        }

        // 发送应用启动完成的通知
        // 让其他组件知道应用已准备好接受交互
        NotificationCenter.postApplicationDidFinishLaunching()
    }

    /// 恢复保存的窗口状态
    ///
    /// 在应用启动时调用，恢复上次保存的窗口状态。
    /// 如果没有保存的状态，则不执行任何操作（由 SwiftUI 自动创建默认窗口）。
    private func restoreSavedWindowStates() {
        let routes = WindowManager.shared.loadSavedWindowStates()
        guard !routes.isEmpty else {
            if Self.verbose {
                AppLogger.core.info("\(self.t)📂 没有保存的窗口状态，使用默认窗口")
            }
            return
        }

        // 恢复保存的窗口
        for route in routes {
            NotificationCenter.default.post(
                name: .openWindowWithRoute,
                object: nil,
                userInfo: ["route": route]
            )
        }

        if Self.verbose {
            AppLogger.core.info("\(self.t)📂 已恢复 \(routes.count) 个窗口")
        }
    }

    /// 应用即将终止
    ///
    /// 在应用退出前调用。
    /// 执行清理操作：
    /// 1. 记录终止日志
    /// 2. 保存窗口状态
    /// 3. 清理各个控制器
    /// 4. 发送终止通知
    func applicationWillTerminate(_ notification: Notification) {
        if Self.verbose {
            AppLogger.core.info("\(self.t)应用即将终止")
        }

        // 保存窗口状态，用于下次启动恢复
        WindowManager.shared.saveWindowStates()

        // 停止磁盘日志收集，flush 剩余条目
        FileLogCoordinator.shared.stop()

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
        if let existingWindowId = WindowManager.shared.findWindow(withProject: path) {
            // 聚焦到已有窗口
            WindowManager.shared.activateWindow(existingWindowId)
            if Self.verbose {
                AppLogger.core.info("\(self.t)📂 项目已在窗口 \(existingWindowId.uuidString.prefix(8)) 中打开，聚焦该窗口")
            }
            return
        }

        // 创建新窗口打开项目
        let route = LumiWindowRoute(projectPath: path)
        NotificationCenter.default.post(
            name: .openWindowWithRoute,
            object: nil,
            userInfo: ["route": route]
        )

        if Self.verbose {
            AppLogger.core.info("\(self.t)📂 在新窗口中打开项目: \(path)")
        }
    }

    /// 在当前活跃窗口的编辑器中打开文件
    ///
    /// - Parameter url: 文件 URL
    private func openFileInActiveWindow(url: URL) {
        // 通知活跃窗口打开文件
        NotificationCenter.default.post(
            name: .openFileInEditor,
            object: nil,
            userInfo: ["url": url]
        )

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
        statusBarController?.setupMenuBar(pluginProvider: PluginVM.shared)
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
        .inRootView()
        .withDebugBar()
}
