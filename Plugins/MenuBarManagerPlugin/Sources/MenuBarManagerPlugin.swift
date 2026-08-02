import AppKit
import AppUpdatePlugin
import Combine
import Foundation
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Menu Bar Manager Plugin
@MainActor
public final class MenuBarManagerPlugin: LumiPlugin, MenuBarPresenting {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-manager")
    nonisolated public static let verbose = false

    public let id = "com.coffic.lumi.plugin.menubar-manager"
    public let name = "Menu Bar Manager"
    public let order = 300
    public let policy: LumiPluginPolicy = .alwaysOn

    private weak var kernel: LumiKernel?
    private(set) public var isMenuBarPresented: Bool = false
    private var presentedMenuBarContentItems: [LumiMenuBarContentItem] = []
    private var presentedMenuBarPopupItems: [LumiMenuBarPopupItem] = []
    private var statusItem: NSStatusItem?
    private var hostingView: MenuBarHostingView<MenuBarIconView>?
    private var popover: NSPopover?
    private var workspaceObservation: AnyCancellable?
    private var applicationResignActiveObservation: AnyCancellable?
    private var systemAppearanceObservation: NSObjectProtocol?
    private var applicationAppearanceObservation: NSKeyValueObservation?
    private var menuBarColorScheme: ColorScheme = SystemAppearanceResolver.effectiveColorScheme

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        self.kernel = kernel
        try kernel.registerService(MenuBarPresenting.self, self)
    }

    public func onReady(kernel: LumiKernel) async throws {
        self.kernel = kernel
        if let storage = kernel.storage {
            MenuBarManagerPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: "Menu Bar Manager",
                systemImage: "menubar.rectangle",
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                MenuBarSettingsView()
            },
        ]
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] {
        [
            MenuBarContentItem(id: "\(id).logo") {
                MenuBarLogoView(kernel: kernel)
            }
        ]
    }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}

    // MARK: - MenuBarPresenting

    public func presentMenuBar(
        contentItems: [LumiMenuBarContentItem],
        popupItems: [LumiMenuBarPopupItem]
    ) {
        presentedMenuBarContentItems = Self.sortedMenuBarContentItems(contentItems)
        presentedMenuBarPopupItems = Self.sortedMenuBarPopupItems(popupItems)
        isMenuBarPresented = true
        ensureStatusItem()
        updateMenuBarPresentation()
        startObservingWorkspaceChangesIfNeeded()
    }

    public func refreshMenuBar(
        contentItems: [LumiMenuBarContentItem],
        popupItems: [LumiMenuBarPopupItem]
    ) {
        if !isMenuBarPresented {
            presentMenuBar(contentItems: contentItems, popupItems: popupItems)
            return
        }

        presentedMenuBarContentItems = Self.sortedMenuBarContentItems(contentItems)
        presentedMenuBarPopupItems = Self.sortedMenuBarPopupItems(popupItems)
        updateMenuBarPresentation()
    }

    public func dismissMenuBar() {
        isMenuBarPresented = false
        presentedMenuBarContentItems.removeAll()
        presentedMenuBarPopupItems.removeAll()
        workspaceObservation?.cancel()
        workspaceObservation = nil
        applicationResignActiveObservation?.cancel()
        applicationResignActiveObservation = nil
        if let systemAppearanceObservation {
            DistributedNotificationCenter.default().removeObserver(systemAppearanceObservation)
        }
        systemAppearanceObservation = nil
        applicationAppearanceObservation = nil

        popover?.close()
        popover = nil

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        hostingView = nil
    }

    // MARK: - Private

    private func ensureStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }

        let hostingView = MenuBarHostingView(rootView: MenuBarIconView(contentItems: presentedMenuBarContentItems))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        self.hostingView = hostingView

        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            hostingView.heightAnchor.constraint(equalToConstant: 22),
        ])

        configurePopoverIfNeeded()
    }

    private func configurePopoverIfNeeded() {
        guard popover == nil else { return }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 280, height: 1)
        popover.contentViewController = makePopupHostingController()
        self.popover = popover
        startObservingApplicationResignActiveIfNeeded()
        startObservingSystemAppearanceChangesIfNeeded()
        syncPopoverWindowAppearance()
    }

    private func updateMenuBarPresentation() {
        guard let statusItem, let button = statusItem.button else { return }

        hostingView?.rootView = MenuBarIconView(contentItems: presentedMenuBarContentItems)

        if let popover {
            popover.contentViewController = makePopupHostingController()
            popover.contentSize = popover.contentViewController?.view.fittingSize ?? NSSize(width: 280, height: 1)
            syncPopoverWindowAppearance()
        }

        button.needsDisplay = true
    }

    private func makePopupHostingController() -> NSHostingController<MenuBarPopupView> {
        NSHostingController(
            rootView: MenuBarPopupView(
                colorScheme: menuBarColorScheme,
                popupItems: presentedMenuBarPopupItems,
                onShowMainWindow: { [weak self] in self?.showMainWindow() },
                onCheckForUpdates: { [weak self] in self?.checkForUpdates() },
                onQuit: { [weak self] in self?.quitApp() }
            )
        )
    }

    private func startObservingWorkspaceChangesIfNeeded() {
        guard workspaceObservation == nil, let kernel, let workspace = kernel.workspace else { return }
        guard let observable = workspace as? any ObservableObject else { return }

        let publisher = observable.objectWillChange as! ObservableObjectPublisher
        workspaceObservation = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.refreshFromKernel()
                }
            }
    }

    private func startObservingApplicationResignActiveIfNeeded() {
        guard applicationResignActiveObservation == nil else { return }

        applicationResignActiveObservation = NotificationCenter.default
            .publisher(for: NSApplication.didResignActiveNotification, object: NSApp)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.popover?.performClose(nil)
            }
    }

    private func startObservingSystemAppearanceChangesIfNeeded() {
        if systemAppearanceObservation == nil {
            systemAppearanceObservation = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshMenuBarSystemAppearance()
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    self?.refreshMenuBarSystemAppearance()
                }
            }
        }

        guard applicationAppearanceObservation == nil else { return }
        applicationAppearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshMenuBarSystemAppearance()
            }
        }
    }

    private func refreshMenuBarSystemAppearance() {
        let latestScheme = SystemAppearanceResolver.effectiveColorScheme
        guard latestScheme != menuBarColorScheme else {
            syncPopoverWindowAppearance()
            return
        }

        menuBarColorScheme = latestScheme
        if let popover {
            popover.contentViewController = makePopupHostingController()
            popover.contentSize = popover.contentViewController?.view.fittingSize ?? NSSize(width: 280, height: 1)
        }
        syncPopoverWindowAppearance()
    }

    private func syncPopoverWindowAppearance() {
        guard let view = popover?.contentViewController?.view else { return }
        let appearanceName: NSAppearance.Name = menuBarColorScheme == .dark ? .darkAqua : .aqua
        let appearance = NSAppearance(named: appearanceName)
        view.appearance = appearance
        view.window?.appearance = appearance
        view.needsDisplay = true
    }

    private func refreshFromKernel() {
        guard let kernel else { return }
        refreshMenuBar(
            contentItems: kernel.workspace?.allMenuBarContents ?? [],
            popupItems: kernel.workspace?.allMenuBarPopups ?? []
        )
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let statusItem, let button = statusItem.button else { return }
        guard let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        refreshMenuBarSystemAppearance()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        syncPopoverWindowAppearance()
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first {
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func sortedMenuBarContentItems(_ items: [LumiMenuBarContentItem]) -> [LumiMenuBarContentItem] {
        items.sorted {
            if $0.order == $1.order { return $0.id < $1.id }
            return $0.order < $1.order
        }
    }

    private static func sortedMenuBarPopupItems(_ items: [LumiMenuBarPopupItem]) -> [LumiMenuBarPopupItem] {
        items.sorted {
            if $0.order == $1.order { return $0.id < $1.id }
            return $0.order < $1.order
        }
    }
}

enum MenuBarManagerPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.coffic.lumi", isDirectory: true)
    }()
}
