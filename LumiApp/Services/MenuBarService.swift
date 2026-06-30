import AppKit
import LumiCoreKit
import LumiUI
import SwiftUI

@MainActor
final class MenuBarService: NSObject, NSPopoverDelegate {
    private let pluginService: PluginService
    private var statusItem: NSStatusItem?
    private var hostingView: MenuBarHostingView<MenuBarIconView>?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var contentTimer: DispatchSourceTimer?
    private let contentRefreshInterval: TimeInterval = 1.0
    private var effectiveAppearanceObservation: NSKeyValueObservation?
    private var windowAppearanceObservation: NSKeyValueObservation?
    private var buttonWindowObservation: NSKeyValueObservation?
    nonisolated(unsafe) private var systemThemeObserver: NSObjectProtocol?
    nonisolated(unsafe) private var themeSyncObserver: NSObjectProtocol?

    init(pluginService: PluginService) {
        self.pluginService = pluginService
        super.init()
        observeSystemAppearanceChanges()
        observeThemeWindowSync()
        scheduleMenuBarSetup()
    }

    deinit {
        if let systemThemeObserver {
            DistributedNotificationCenter.default.removeObserver(systemThemeObserver)
        }
        if let themeSyncObserver {
            NotificationCenter.default.removeObserver(themeSyncObserver)
        }
    }

    func refresh() {
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

        let items = pluginService.menuBarContentItems(context: menuBarContext)
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
    }

    private func makeMenuBarIconView(items: [LumiMenuBarContentItem]) -> MenuBarIconView {
        MenuBarIconView(contentItems: items)
    }

    private func replaceMenuBarContent() {
        guard let button = statusItem?.button else { return }

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
    private func restoreMenuBarSystemAppearance() {
        ThemeWindowAppearanceSync.restoreMenuBarSystemAppearance()
        statusItem?.button?.appearance = nil
        hostingView?.appearance = nil
    }

    private func observeMenuBarAppearance(button: NSStatusBarButton) {
        guard effectiveAppearanceObservation == nil else { return }

        effectiveAppearanceObservation = button.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.replaceMenuBarContent()
            }
        }

        buttonWindowObservation = button.observe(\.window, options: [.new]) { [weak self] button, _ in
            Task { @MainActor in
                self?.observeWindowAppearance(button.window)
                self?.replaceMenuBarContent()
            }
        }

        observeWindowAppearance(button.window)
    }

    private func observeWindowAppearance(_ window: NSWindow?) {
        windowAppearanceObservation?.invalidate()
        windowAppearanceObservation = window?.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.replaceMenuBarContent()
            }
        }
    }

    private func observeSystemAppearanceChanges() {
        systemThemeObserver = DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
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
            Task { @MainActor in
                self?.replaceMenuBarContent()
            }
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
    }

    func popoverDidClose(_ notification: Notification) {
        removeEventMonitor()
    }

}
