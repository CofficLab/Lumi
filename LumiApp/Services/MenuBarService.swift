import AppKit
import LumiCoreKit
import SwiftUI

@MainActor
final class MenuBarService: NSObject, NSPopoverDelegate {
    private let pluginService: PluginService
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var contentTimer: DispatchSourceTimer?
    private let contentRefreshInterval: TimeInterval = 1.0
    nonisolated(unsafe) private var systemThemeObserver: NSObjectProtocol?

    init(pluginService: PluginService) {
        self.pluginService = pluginService
        super.init()
        observeSystemThemeChanges()
        scheduleMenuBarSetup()
    }

    deinit {
        if let systemThemeObserver {
            DistributedNotificationCenter.default.removeObserver(systemThemeObserver)
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

            self.updateButtonImage()

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

        // 占位 template 图，避免部分 macOS 版本非活跃屏幕着色异常（见 Stats #2131）。
        button.image = NSImage()
        button.target = self
        button.action = #selector(togglePopover)

        updateButtonImage()
        startContentTimer()
    }

    private func updateButtonImage() {
        guard let button = statusItem?.button else { return }

        let items = pluginService.menuBarContentItems(context: menuBarContext)
        let view = MenuBarIconView(contentItems: items)

        guard let image = MenuBarTemplateImageRenderer.render(view) else {
            return
        }

        button.image = image
        button.image?.isTemplate = true
        statusItem?.length = max(24, image.size.width + 4)
    }

    private func observeSystemThemeChanges() {
        systemThemeObserver = DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonImage()
            }
        }
    }

    private func startContentTimer() {
        guard contentTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + contentRefreshInterval, repeating: contentRefreshInterval)
        timer.setEventHandler { [weak self] in
            self?.updateButtonImage()
        }
        timer.activate()
        contentTimer = timer
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
