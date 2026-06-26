import AppKit
import LumiCoreKit
import SwiftUI

@MainActor
final class MenuBarService: NSObject, NSPopoverDelegate {
    private let pluginService: PluginService
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    /// CPU/内存/网速等内容随时间变化，但状态栏图标渲染为单张模板图快照，
    /// 必须定时重绘才能让图表/数值实时更新。
    private var contentTimer: DispatchSourceTimer?

    /// 重绘间隔（秒）。与 DeviceInfo 的 ~80ms 去抖相协调，兼顾流畅度与功耗。
    private let contentRefreshInterval: TimeInterval = 1.0

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

            self.updateStatusItemImage()

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

        // 先用一个占位长度创建 status item，待图片渲染后按真实宽度校正。
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover)

        updateStatusItemImage()
        startContentTimer()
    }

    /// 把菜单栏内容（Logo + CPU/内存/网速）渲染成单色模板图交给系统着色。
    ///
    /// 模板图（`isTemplate = true`）不依赖任何 `NSAppearance` 求值，系统会按菜单栏
    /// 真实外观（系统明暗 + 壁纸亮度自适应）自动涂黑或涂白，永远与其它系统图标一致，
    /// 不受 Lumi 主题窗口外观污染。
    private func updateStatusItemImage() {
        guard let button = statusItem?.button else { return }

        let items = pluginService.menuBarContentItems(context: menuBarContext)
        let iconView = MenuBarIconView(contentItems: items)

        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        guard let image = renderer.nsImage else { return }

        image.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        statusItem?.length = image.size.width
    }

    /// 启动定时重绘，让菜单栏内的 CPU/内存/网速图表实时刷新。
    private func startContentTimer() {
        guard contentTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + contentRefreshInterval, repeating: contentRefreshInterval)
        timer.setEventHandler { [weak self] in
            self?.updateStatusItemImage()
        }
        timer.activate()
        contentTimer = timer
    }

    private func stopContentTimer() {
        contentTimer?.cancel()
        contentTimer = nil
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
