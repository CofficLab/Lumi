import AppKit
import Combine
import MagicKit
import SwiftUI
/// 窗口管理器
///
/// 负责管理所有窗口的生命周期和状态同步
@MainActor
final class WindowManager: ObservableObject, SuperLog {
    static let shared = WindowManager()
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose = false

    // MARK: - Published Properties

    /// 所有窗口状态
    @Published private(set) var windowStates: [WindowState] = []

    /// 当前活跃窗口 ID
    @Published private(set) var activeWindowId: UUID?

    /// 窗口计数（用于菜单显示）
    var windowCount: Int { windowStates.count }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var windowIdMap: [NSWindow: UUID] = [:]

    // MARK: - Initialization

    private init() {
        setupNotifications()
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 窗口管理器初始化完成")
        }
    }

    // MARK: - Window Management

    /// 注册新窗口
    /// - Parameter state: 窗口状态
    func registerWindow(_ state: WindowState) {
        guard !windowStates.contains(where: { $0.id == state.id }) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 窗口已存在: \(state.id.uuidString.prefix(8))")
            }
            return
        }

        windowStates.append(state)
        setActiveWindow(state.id)

        if Self.verbose {
            let count = self.windowStates.count
            AppLogger.core.info("\(Self.t) 注册窗口: \(state.id.uuidString.prefix(8)), 总窗口数: \(count)")
        }
    }

    /// 注销窗口
    /// - Parameter windowId: 窗口 ID
    func unregisterWindow(_ windowId: UUID) {
        windowStates.removeAll { $0.id == windowId }

        // 如果关闭的是活跃窗口，切换到下一个窗口
        if activeWindowId == windowId {
            activeWindowId = windowStates.first?.id
        }
        
        NotificationCenter.postWindowClosed(windowId)

        if Self.verbose {
            let count = self.windowStates.count
            AppLogger.core.info("\(Self.t) 注销窗口: \(windowId.uuidString.prefix(8)), 剩余窗口数: \(count)")
        }
    }

    /// 设置活跃窗口
    /// - Parameter windowId: 窗口 ID
    func setActiveWindow(_ windowId: UUID) {
        // 更新之前活跃窗口的状态
        if let previousId = activeWindowId,
           let previousWindow = windowStates.first(where: { $0.id == previousId }) {
            previousWindow.setActive(false)
        }

        // 设置新的活跃窗口
        activeWindowId = windowId
        if let window = windowStates.first(where: { $0.id == windowId }) {
            window.setActive(true)
        }

        NotificationCenter.postWindowActivated(windowId)

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 设置活跃窗口: \(windowId.uuidString.prefix(8))")
        }
    }

    /// 获取窗口状态
    /// - Parameter windowId: 窗口 ID
    /// - Returns: 窗口状态
    func getWindowState(_ windowId: UUID) -> WindowState? {
        windowStates.first { $0.id == windowId }
    }

    /// 获取当前活跃窗口状态
    var activeWindowState: WindowState? {
        guard let id = activeWindowId else { return nil }
        return getWindowState(id)
    }

    // MARK: - Window Operations

    /// 打开新窗口
    /// - Parameters:
    ///   - conversationId: 可选的会话 ID
    ///   - projectPath: 可选的项目路径
    func openNewWindow(conversationId: UUID? = nil, projectPath: String? = nil) {
        // 创建新的窗口状态
        let newState = WindowState(
            conversationId: conversationId,
            projectPath: projectPath
        )

        // 先注册窗口状态
        registerWindow(newState)

        // 触发系统新建窗口命令
        // 使用 performSelector 确保在主线程执行
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 打开新窗口: \(newState.id.uuidString.prefix(8))")
        }
    }

    /// 关闭指定窗口
    /// - Parameter windowId: 窗口 ID
    func closeWindow(_ windowId: UUID) {
        // 找到对应的 NSWindow 并关闭
        if let window = windowIdMap.first(where: { $0.value == windowId })?.key {
            window.close()
        }
        unregisterWindow(windowId)
    }

    /// 激活指定窗口
    /// - Parameter windowId: 窗口 ID
    func activateWindow(_ windowId: UUID) {
        guard let window = windowIdMap.first(where: { $0.value == windowId })?.key else { return }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setActiveWindow(windowId)
    }

    /// 关闭所有窗口
    func closeAllWindows() {
        let windowsToClose = Array(windowStates)
        for state in windowsToClose {
            closeWindow(state.id)
        }
    }

    // MARK: - Window Synchronization

    /// 广播事件到所有窗口
    /// - Parameter event: 窗口事件
    func broadcast(_ event: WindowEvent) {
        NotificationCenter.postWindowEvent(event, from: activeWindowId)

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 广播事件: \(String(describing: event))")
        }
    }

    /// 同步会话列表变更
    func syncConversationList() {
        broadcast(.conversationListChanged)
    }

    /// 同步会话内容更新
    /// - Parameter conversationId: 会话 ID
    func syncConversationUpdate(_ conversationId: UUID) {
        broadcast(.conversationUpdated(conversationId))
    }

    // MARK: - NSWindow Tracking

    /// 关联 NSWindow 和窗口状态 ID
    /// - Parameters:
    ///   - window: NSWindow 实例
    ///   - windowId: 窗口状态 ID
    func associateWindow(_ window: NSWindow, with windowId: UUID) {
        windowIdMap[window] = windowId

        // 监听窗口关闭
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        // 监听窗口成为关键窗口
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }

    // MARK: - Notification Handlers

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowId = windowIdMap[window] else { return }

        unregisterWindow(windowId)
        windowIdMap.removeValue(forKey: window)
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowId = windowIdMap[window] else { return }

        setActiveWindow(windowId)
    }

    private func setupNotifications() {
        // 监听应用激活状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        // 应用重新激活时，确保有活跃窗口
        if activeWindowId == nil, let firstWindow = windowStates.first {
            setActiveWindow(firstWindow.id)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
