import AppKit
import Combine
import SwiftUI

/// 窗口管理器 VM
///
/// 负责管理所有窗口的生命周期和状态同步。
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
@MainActor
final class AppWindowManagerVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "🪟"
    nonisolated static let verbose: Bool = true

    // MARK: - Published Properties

    /// 所有 WindowContainer
    @Published private(set) var windowContainers: [WindowContainer] = []

    /// 当前活跃窗口 ID
    @Published private(set) var activeWindowId: UUID?

    /// 窗口计数（用于菜单显示）
    var windowCount: Int { windowContainers.count }

    /// 启动时窗口状态恢复是否已完成
    @Published private(set) var hasCompletedInitialStateRestoration: Bool = false

    /// 启动时窗口状态恢复是否已开始
    @Published private(set) var hasStartedInitialStateRestoration: Bool = false

    // MARK: - Private Properties

    private var windowIdMap: [NSWindow: UUID] = [:]

    /// 窗口作用域快速查找映射（窗口 ID -> WindowContainer）
    private var containerMap: [UUID: WindowContainer] = [:]

    private var isTerminating = false
    private var hasRegisteredWindow = false

    // MARK: - Initialization

    init() {
        setupNotifications()
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ 窗口管理器初始化完成")
        }
    }

    // MARK: - Window Management

    /// 注册新窗口
    func registerContainer(_ container: WindowContainer) {
        guard !windowContainers.contains(where: { $0.id == container.id }) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 窗口已存在: \(container.id.uuidString.prefix(8))")
            }
            return
        }

        hasRegisteredWindow = true
        windowContainers.append(container)
        containerMap[container.id] = container
        setActiveWindow(container.id)
        persistWindowIds()

        if Self.verbose {
            let count = self.windowContainers.count
            AppLogger.core.info("\(Self.t) 注册窗口: \(container.id.uuidString.prefix(8)), 总窗口数: \(count)")
        }
    }

    /// 窗口关闭时注销，仅发出通知（存储由插件负责）
    func unregisterContainer(_ windowId: UUID) {
        RootContainer.shared.toolService.clearConversationListContext(for: windowId)
        windowContainers.removeAll { $0.id == windowId }
        containerMap.removeValue(forKey: windowId)

        if activeWindowId == windowId {
            activeWindowId = windowContainers.first?.id
        }
        if !isTerminating {
            persistWindowIds()
        }

        NotificationCenter.postWindowClosed(windowId)
    }

    /// 设置活跃窗口
    func setActiveWindow(_ windowId: UUID) {
        // 更新之前活跃窗口的状态
        if let previousId = activeWindowId,
           let previousScope = containerMap[previousId] {
            previousScope.setActive(false)
        }

        // 设置新的活跃窗口
        activeWindowId = windowId
        if let scope = containerMap[windowId] {
            scope.setActive(true)
        }

        if Self.verbose {
            AppLogger.core.info("\(Self.t) 设置活跃窗口: \(windowId.uuidString.prefix(8))")
        }
    }

    /// 获取当前活跃窗口的 WindowContainer
    var activeWindowContainer: WindowContainer? {
        guard let id = activeWindowId else { return nil }
        return containerMap[id]
    }

    /// 获取指定窗口的 WindowContainer
    func getContainer(_ windowId: UUID) -> WindowContainer? {
        containerMap[windowId]
    }

    /// 查找已打开指定项目的窗口
    func findWindow(withProject projectPath: String) -> UUID? {
        windowContainers.first { $0.projectPath == projectPath }?.id
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
        activateWindowIfPresent(windowId)
    }

    /// 激活当前最合适的主窗口。
    @discardableResult
    func activatePreferredWindow() -> Bool {
        if let activeWindowId, activateWindowIfPresent(activeWindowId) {
            return true
        }

        for container in windowContainers where activateWindowIfPresent(container.id) {
            return true
        }

        if let windowId = windowIdMap.values.first, activateWindowIfPresent(windowId) {
            return true
        }

        return false
    }

    /// 关闭所有窗口
    func closeAllWindows() {
        let windowsToClose = Array(windowContainers)
        for scope in windowsToClose {
            closeWindow(scope.id)
        }
    }

    @discardableResult
    private func activateWindowIfPresent(_ windowId: UUID) -> Bool {
        guard let window = window(for: windowId) else { return false }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setActiveWindow(windowId)
        return true
    }

    // MARK: - NSWindow Tracking

    /// 关联 NSWindow 和窗口 ID
    func associateWindow(_ window: NSWindow, with windowId: UUID) {
        if windowIdMap[window] == windowId {
            return
        }

        if windowIdMap[window] != nil {
            removeWindowObservers(for: window)
        }

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

        unregisterContainer(windowId)
        windowIdMap.removeValue(forKey: window)
        removeWindowObservers(for: window)
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    private func persistWindowIds() {
        let ids = windowContainers.map(\.id)
        guard Self.shouldPersistWindowIds(ids, hasRegisteredWindow: hasRegisteredWindow) else {
            return
        }

        CoreWindowIDStore.saveWindowIds(ids)
    }

    nonisolated static func shouldPersistWindowIds(_ ids: [UUID], hasRegisteredWindow: Bool) -> Bool {
        hasRegisteredWindow || !ids.isEmpty
    }

    private func removeWindowObservers(for window: NSWindow) {
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.willCloseNotification,
            object: window
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }

    @objc private func applicationWillTerminate() {
        isTerminating = true
        persistWindowIds()
    }

    @objc private func applicationDidBecomeActive() {
        if activeWindowId == nil, let firstScope = windowContainers.first {
            setActiveWindow(firstScope.id)
        }
    }

    /// 尝试开始启动时的窗口状态恢复（全局仅一次）
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
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
