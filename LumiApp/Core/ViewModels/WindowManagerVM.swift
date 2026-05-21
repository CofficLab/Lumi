import AppKit
import Combine
import MagicKit
import SwiftUI

/// 窗口管理器 VM
///
/// 负责管理所有窗口的生命周期和状态同步。
/// 直接管理 WindowScope 实例，不再使用 WindowState。
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
@MainActor
final class WindowManagerVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose: Bool = false

    // MARK: - Published Properties

    /// 所有窗口作用域
    @Published private(set) var windowScopes: [WindowScope] = []

    /// 当前活跃窗口 ID
    @Published private(set) var activeWindowId: UUID?

    /// 启动时保存的窗口状态是否已完成恢复
    @Published private(set) var hasCompletedInitialStateRestoration: Bool = false

    /// 启动时保存的窗口状态是否已经开始恢复
    @Published private(set) var hasStartedInitialStateRestoration: Bool = false

    /// 窗口计数（用于菜单显示）
    var windowCount: Int { windowScopes.count }

    // MARK: - Private Properties

    private var windowIdMap: [NSWindow: UUID] = [:]

    /// 窗口作用域快速查找映射（窗口 ID -> WindowScope）
    private var scopeMap: [UUID: WindowScope] = [:]

    // MARK: - Initialization

    init() {
        setupNotifications()
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 窗口管理器初始化完成")
        }
    }

    // MARK: - Window Management

    /// 注册新窗口
    func registerScope(_ scope: WindowScope) {
        guard !windowScopes.contains(where: { $0.id == scope.id }) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 窗口已存在: \(scope.id.uuidString.prefix(8))")
            }
            return
        }

        windowScopes.append(scope)
        scopeMap[scope.id] = scope
        setActiveWindow(scope.id)

        if Self.verbose {
            let count = self.windowScopes.count
            AppLogger.core.info("\(Self.t) 注册窗口: \(scope.id.uuidString.prefix(8)), 总窗口数: \(count)")
        }
    }

    /// 窗口关闭时注销，仅发出通知（存储由插件负责）
    func unregisterScope(_ windowId: UUID) {
        scopeMap[windowId]?.cleanup()
        windowScopes.removeAll { $0.id == windowId }
        scopeMap.removeValue(forKey: windowId)

        if activeWindowId == windowId {
            activeWindowId = windowScopes.first?.id
        }

        NotificationCenter.postWindowClosed(windowId)
    }

    /// 设置活跃窗口
    func setActiveWindow(_ windowId: UUID) {
        // 更新之前活跃窗口的状态
        if let previousId = activeWindowId,
           let previousScope = scopeMap[previousId] {
            previousScope.setActive(false)
        }

        // 设置新的活跃窗口
        activeWindowId = windowId
        if let scope = scopeMap[windowId] {
            scope.setActive(true)
        }

        NotificationCenter.postWindowActivated(windowId)

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 设置活跃窗口: \(windowId.uuidString.prefix(8))")
        }
    }

    /// 获取当前活跃窗口的 WindowScope
    var activeWindowScope: WindowScope? {
        guard let id = activeWindowId else { return nil }
        return scopeMap[id]
    }

    /// 获取指定窗口的 WindowScope
    func getScope(_ windowId: UUID) -> WindowScope? {
        scopeMap[windowId]
    }

    /// 查找已打开指定项目的窗口
    func findWindow(withProject projectPath: String) -> UUID? {
        windowScopes.first { $0.projectPath == projectPath }?.id
    }

    /// 查找已打开指定会话的窗口
    func findWindow(withConversation conversationId: UUID) -> UUID? {
        windowScopes.first { $0.selectedConversationId == conversationId }?.id
    }

    // MARK: - Window Operations

    /// 根据 ID 查找关联的 NSWindow
    func window(for windowId: UUID) -> NSWindow? {
        windowIdMap.first(where: { $0.value == windowId })?.key
    }

    /// 关闭指定窗口
    func closeWindow(_ windowId: UUID) {
        if let window = window(for: windowId) {
            window.close()
        }
    }

    /// 激活指定窗口
    func activateWindow(_ windowId: UUID) {
        guard let window = window(for: windowId) else { return }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setActiveWindow(windowId)
    }

    /// 关闭所有窗口
    func closeAllWindows() {
        let windowsToClose = Array(windowScopes)
        for scope in windowsToClose {
            closeWindow(scope.id)
        }
    }

    // MARK: - Window Synchronization

    /// 广播事件到所有窗口
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
    func syncConversationUpdate(_ conversationId: UUID) {
        broadcast(.conversationUpdated(conversationId))
    }

    // MARK: - NSWindow Tracking

    /// 关联 NSWindow 和窗口 ID
    func associateWindow(_ window: NSWindow, with windowId: UUID) {
        windowIdMap[window] = windowId

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

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

        unregisterScope(windowId)
        windowIdMap.removeValue(forKey: window)
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let windowId = windowIdMap[window] else { return }

        setActiveWindow(windowId)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        if activeWindowId == nil, let firstScope = windowScopes.first {
            setActiveWindow(firstScope.id)
        }
    }

    // MARK: - Window State Restoration

    /// 从路由列表恢复窗口状态（纯内存操作，不涉及磁盘）。
    ///
    /// 启动时插件读取磁盘并调用此方法。
    /// SwiftUI 已创建了一个默认窗口，因此第一条路由应用到现有窗口；
    /// 只有多余的路由才需要再打开新窗口。
    func restoreSavedWindowStates(
        routes: [LumiWindowRoute],
        openAdditionalWindow: (LumiWindowRoute) -> Void
    ) {
        guard !hasCompletedInitialStateRestoration else { return }
        hasStartedInitialStateRestoration = true

        guard !routes.isEmpty else {
            markInitialStateRestorationComplete()
            return
        }

        var remainingRoutes = routes
        if let firstScope = windowScopes.first {
            let firstRoute = remainingRoutes.removeFirst()
            firstScope.applyRoute(firstRoute)
        }

        for route in remainingRoutes {
            openAdditionalWindow(route)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📂 已恢复 \(routes.count) 个窗口状态，额外打开 \(remainingRoutes.count) 个窗口")
        }

        markInitialStateRestorationComplete()
    }

    func beginInitialStateRestorationIfNeeded() -> Bool {
        guard !hasStartedInitialStateRestoration,
              !hasCompletedInitialStateRestoration else {
            return false
        }

        hasStartedInitialStateRestoration = true
        return true
    }

    func markInitialStateRestorationComplete() {
        guard !hasCompletedInitialStateRestoration else { return }
        hasStartedInitialStateRestoration = true
        hasCompletedInitialStateRestoration = true
        NotificationCenter.postInitialWindowStateRestorationDidFinish()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
