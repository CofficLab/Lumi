import AppKit
import Combine
import LumiCoreKit
import LumiUI
import os
import SuperLogKit
import SwiftUI

@MainActor
final class MenuBarService: NSObject, NSPopoverDelegate, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.menu-bar")
    nonisolated static let emoji = "📋"
    nonisolated(unsafe) static var verbose: Bool = false

    private let pluginService: PluginService
    private let lumiCore: LumiCoreAccessing
    private var statusItem: NSStatusItem?
    private var hostingView: MenuBarHostingView<MenuBarIconView>?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var contentTimer: DispatchSourceTimer?
    private let contentRefreshInterval: TimeInterval = 1.0
    private var windowAppearanceObservation: NSKeyValueObservation?
    private var buttonWindowObservation: NSKeyValueObservation?
    private nonisolated(unsafe) var systemThemeObserver: NSObjectProtocol?
    private nonisolated(unsafe) var themeSyncObserver: NSObjectProtocol?
    private nonisolated(unsafe) var pluginsChangedObserver: NSObjectProtocol?

    /// 订阅 `LogoRegistry.$bestItem`：插件贡献的 Logo 就绪后，
    /// 自动触发菜单栏内容重建，让 `LogoView(scene: .statusBar)` 拿到正确的 Logo。
    private nonisolated(unsafe) var logoRegistryCancellable: AnyCancellable?

    init(pluginService: PluginService, lumiCore: LumiCoreAccessing) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 MenuBarService")
        }

        self.pluginService = pluginService
        self.lumiCore = lumiCore
        super.init()
        observeSystemAppearanceChanges()
        observeThemeWindowSync()
        observeLogoRegistry()
        observePluginStateChanges()
        scheduleMenuBarSetup()

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ MenuBarService 初始化完成")
        }
    }

    deinit {
        if let systemThemeObserver {
            DistributedNotificationCenter.default.removeObserver(systemThemeObserver)
        }
        if let themeSyncObserver {
            NotificationCenter.default.removeObserver(themeSyncObserver)
        }
        if let pluginsChangedObserver {
            NotificationCenter.default.removeObserver(pluginsChangedObserver)
        }
        logoRegistryCancellable?.cancel()
    }

    func refresh() {
        if Self.verbose {
            Self.logger.info("\(Self.t)刷新菜单栏")
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if self.statusItem == nil {
                self.setupMenuBar()
                return
            }

            self.replaceMenuBarContent()

            if self.popover?.isShown == true {
                self.popover?.contentViewController = NSHostingController(rootView: self.makePopupView())
            }
        }
    }

    private var menuBarContext: LumiPluginContext {
        LumiPluginContext(
            activeSectionID: "system.menu-bar",
            activeSectionTitle: "Menu Bar"
        )
    }

    private func scheduleMenuBarSetup() {
        DispatchQueue.main.async { [weak self] in
            self?.setupMenuBar()
        }
    }

    private func setupMenuBar() {
        if statusItem != nil {
            refresh()
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)设置菜单栏")
        }

        let items = pluginService.menuBarContentItems(context: menuBarContext)
        if Self.verbose {
            Self.logger.info("\(Self.t)菜单栏项目数: \(items.count)")
        }

        statusItem = NSStatusBar.system.statusItem(withLength: menuBarWidthEstimate(for: items))

        guard let button = statusItem?.button else {
            return
        }

        let hostingView = MenuBarHostingView(rootView: makeMenuBarIconView(items: items))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hostingView

        button.image = nil
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)
        button.target = self
        button.action = #selector(togglePopover)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hostingView.heightAnchor.constraint(equalToConstant: 22),
        ])

        restoreMenuBarSystemAppearance()
        observeMenuBarAppearance(button: button)

        // 延迟更新以确保布局完成
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItemLength()
        }

        startContentTimer()

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 菜单栏设置完成")
        }
    }

    private func makeMenuBarIconView(items: [LumiMenuBarContentItem]) -> MenuBarIconView {
        MenuBarIconView(contentItems: items, lumiCore: lumiCore)
    }

    private func replaceMenuBarContent() {
        guard let button = statusItem?.button else { return }

        if Self.verbose {
            Self.logger.info("\(Self.t)replaceMenuBarContent 进入")
        }

        restoreMenuBarSystemAppearance()

        MenuBarAppearance.performAsCurrent(for: button) {
            let items = pluginService.menuBarContentItems(context: menuBarContext)
            hostingView?.rootView = makeMenuBarIconView(items: items)
        }

        NotificationCenter.default.post(name: .lumiMenuBarAppearanceDidChange, object: button)
        hostingView?.needsDisplay = true

        // 延迟更新以避免在 SwiftUI 布局过程中触发递归布局
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItemLength()
        }
    }

    /// 清除 Lumi 主题同步对菜单栏系统窗口的 `appearance` 污染。
    ///
    /// 幂等守卫：仅当当前 `appearance != nil` 时才赋 `nil`。
    /// 若无条件赋 `nil`，在 appearance 已为 nil 时也会再次改写 `effectiveAppearance`，
    /// 触发 `observeMenuBarAppearance` 的 KVO → `replaceMenuBarContent` → 本方法，
    /// 形成 KVO 自激振荡，导致主线程持续 100% CPU。
    private func restoreMenuBarSystemAppearance() {
        ThemeWindowAppearanceSync.restoreMenuBarSystemAppearance()
        if let button = statusItem?.button, button.appearance != nil {
            button.appearance = nil
        }
        if let hostingView, hostingView.appearance != nil {
            hostingView.appearance = nil
        }
    }

    private func observeMenuBarAppearance(button: NSStatusBarButton) {
        guard buttonWindowObservation == nil else { return }

        // 注意：不要观察 button.effectiveAppearance / window.effectiveAppearance。
        //
        // status item 的 effectiveAppearance 由系统综合「窗口主题」与「菜单栏壁纸自适应」计算，
        // 是一个派生值。replaceMenuBarContent → restoreMenuBarSystemAppearance 把 appearance 置 nil
        // 后，系统重新计算时会在 NSAppearanceNameDarkAqua 与 NSAppearanceNameVibrantLight 之间
        // 来回横跳，触发 effectiveAppearance 的 KVO，而 KVO 又回调 replaceMenuBarContent，
        // 形成跨 runloop 的自激振荡，导致主线程持续 100% CPU。
        //
        // 真正需要刷新内容的时机（系统主题切换、Lumi 主题同步）已由下面的低频信号覆盖：
        // - observeSystemAppearanceChanges：监听 AppleInterfaceThemeChangedNotification
        // - observeThemeWindowSync：监听 lumiThemeDidSyncWindowAppearances
        // 这里仅保留对 button.window 的观察，用于在窗口挂载/变化时重新布局，不触碰 appearance。

        buttonWindowObservation = button.observe(\.window, options: [.new]) { [weak self] button, _ in
            if Self.verbose {
                Self.logger.info("\(Self.t)KVO[button.window] 变化，更新布局")
            }
            Task { @MainActor in
                self?.observeWindowAppearance(button.window)
                // 延迟更新尺寸，不触发内容重建（避免重启外观振荡）。
                self?.updateStatusItemLength()
            }
        }

        observeWindowAppearance(button.window)
    }

    private func observeWindowAppearance(_ window: NSWindow?) {
        windowAppearanceObservation?.invalidate()
        // 不观察 window.effectiveAppearance，原因同 observeMenuBarAppearance：避免与
        // replaceMenuBarContent 的副作用形成 KVO 自激振荡。仅持有观察引用以备后续扩展。
        windowAppearanceObservation = nil
    }

    private func observeSystemAppearanceChanges() {
        systemThemeObserver = DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if Self.verbose {
                Self.logger.info("\(Self.t)分布式通知[AppleInterfaceTheme] → replaceMenuBarContent")
            }
            Task { @MainActor in
                self?.replaceMenuBarContent()
            }
        }
    }

    private func observeThemeWindowSync() {
        themeSyncObserver = NotificationCenter.default.addObserver(
            forName: .lumiThemeDidSyncWindowAppearances,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if Self.verbose {
                Self.logger.info("\(Self.t)通知[lumiThemeDidSyncWindowAppearances] → replaceMenuBarContent")
            }
            Task { @MainActor in
                self?.replaceMenuBarContent()
            }
        }
    }

    /// 订阅 `LumiCore.logoRegistry.$bestItem`。
    ///
    /// `MenuBarService` 启动时（`init` → `scheduleMenuBarSetup`）会立刻创建 `NSStatusItem`
    /// 并渲染 `MenuBarIconView`，但此时插件的 Logo 贡献可能尚未注册（由 `RootView.body`
    /// 触发的 `registerPluginContributions` 才是真正的注册时机）。结果就是
    /// `LogoView(scene: .statusBar)` 第一次求值时拿到 `bestItem == nil`，
    /// 菜单栏显示一张透明占位图。
    ///
    /// 这里订阅 `@Published` 变更：插件贡献的 Logo 一旦就绪，`bestItem` 立刻变化，
    /// 我们重建菜单栏内容（与系统主题、主题同步共用同一条 `replaceMenuBarContent` 路径），
    /// 让 `LogoView` 在第二轮渲染中拿到正确的 LogoItem。
    ///
    /// 选择 Combine 订阅而不是依赖 `onEnabledPluginsChanged`：
    /// - `onEnabledPluginsChanged` 的语义是「启用列表变了」，跟「Logo 注册了」是两件事，
    ///   用它当信号灯会引入误触发与漏触发；
    /// - `LogoRegistry` 已经是 `ObservableObject`，订阅 `@Published` 是单一事实源路径，
    ///   与 `LogoView` 用 `@ObservedObject` 订阅同一份数据保持一致。
    ///
    /// `dropFirst()` 跳过初始 nil（菜单栏还没创建，按钮状态 item 也是 nil，没必要重建）。
    /// `replaceMenuBarContent` 内部用 `statusItem?.button` 守护，未创建时直接 return，不会崩溃。
    private func observeLogoRegistry() {
        logoRegistryCancellable = lumiCore.logoRegistry
            .$bestItem
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if Self.verbose {
                    Self.logger.info("\(Self.t)LogoRegistry.$bestItem 变化 → replaceMenuBarContent")
                }
                self?.replaceMenuBarContent()
            }
    }

    /// 订阅插件启用状态变化：插件 enable/disable 后菜单栏条目（statusBarItems /
    /// menuBarContentItems 等）会随之变化，需要 `refresh()` 重建。
    /// 原先由 RootContainer fan-out 调用，现在本类自治。
    private func observePluginStateChanges() {
        pluginsChangedObserver = NotificationCenter.default.onLumiEnabledPluginsDidChange { [weak self] in
            self?.refresh()
        }
    }

    private func startContentTimer() {
        // 移除 1 秒轮询定时器
        // 菜单栏内容现在通过事件驱动更新：
        // - 系统外观变化
        // - 主题同步
        // - 按钮外观变化
        // - 窗口外观变化
        // - 插件列表变化（通过 refresh() 方法）
        //
        // 如果需要定期更新，可以将间隔改为 5 秒：
        // guard contentTimer == nil else { return }
        // let timer = DispatchSource.makeTimerSource(queue: .main)
        // timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
        // timer.setEventHandler { [weak self] in
        //     self?.replaceMenuBarContent()
        // }
        // timer.activate()
        // contentTimer = timer
    }

    private func updateStatusItemLength() {
        guard let hostingView, let statusItem else { return }
        hostingView.layoutSubtreeIfNeeded()
        statusItem.length = max(24, hostingView.fittingSize.width)
    }

    private func menuBarWidthEstimate(for items: [LumiMenuBarContentItem]) -> CGFloat {
        max(24, 24 + CGFloat(items.count * 44))
    }

    @objc private func togglePopover() {
        if Self.verbose {
            Self.logger.info("\(self.t)切换弹出窗口")
        }

        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else {
            return
        }

        closePopover()

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: makePopupView())
        self.popover = popover

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        configurePopoverWindowForSpaces()
        addEventMonitor()

        if Self.verbose {
            Self.logger.info("\(self.t)显示弹出窗口")
        }
    }

    private func makePopupView() -> MenuBarPopupView {
        MenuBarPopupView(
            popupItems: pluginService.menuBarPopupItems(context: menuBarContext),
            onShowMainWindow: { [weak self] in
                self?.showMainWindow()
                self?.closePopover()
            },
            onCheckForUpdates: { [weak self] in
                NotificationCenter.postCheckForUpdates()
                self?.closePopover()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    private func showMainWindow() {
        if Self.verbose {
            Self.logger.info("\(self.t)显示主窗口")
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func configurePopoverWindowForSpaces() {
        guard let window = popover?.contentViewController?.view.window else {
            return
        }

        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
    }

    private func addEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        popover = nil
        removeEventMonitor()

        if Self.verbose {
            Self.logger.info("\(self.t)关闭弹出窗口")
        }
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitor()
    }
}
