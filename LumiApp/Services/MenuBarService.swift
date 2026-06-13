import AppKit
import LumiCoreKit
import SwiftUI

@MainActor
final class MenuBarService: NSObject, NSPopoverDelegate {
    private let pluginService: PluginService
    private var statusItem: NSStatusItem?
    private var hostingView: NSHostingView<MenuBarIconView>?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    init(pluginService: PluginService) {
        self.pluginService = pluginService
        super.init()
        scheduleMenuBarSetup()
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

            let items = self.pluginService.menuBarContentItems(context: self.menuBarContext)
            self.hostingView?.rootView = MenuBarIconView(contentItems: items)
            self.statusItem?.length = self.menuBarWidth(for: items)

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
        statusItem = NSStatusBar.system.statusItem(withLength: menuBarWidth(for: items))

        guard let button = statusItem?.button else {
            return
        }

        let rootView = MenuBarIconView(contentItems: items)
        let hostingView = NSHostingView(rootView: rootView)
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
            hostingView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func menuBarWidth(for items: [LumiMenuBarContentItem]) -> CGFloat {
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
