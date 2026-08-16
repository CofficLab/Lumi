import Foundation
import KernelLumi
import LumiUI
import SwiftUI
import os

/// Menu Bar Helper Plugin
///
/// Provides the **Menu Bar Manager** ViewContainer (settings UI for managing
/// menu bar item visibility). The companion `MenuBarManagerPlugin` still owns
/// the NSStatusItem, popover, and logo content rendering.
@MainActor
public final class MenuBarHelperPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.menubar-helper")
    nonisolated public static let verbose = false

    public let id = "com.coffic.lumi.plugin.menubar-helper"
    public var name: String {
        LumiPluginLocalization.string("Menu Bar Manager", bundle: .module)
    }
    public let order = 310
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    private weak var kernel: KernelLumi?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        self.kernel = kernel
    }

    public func onReady(kernel: KernelLumi) async throws {
        self.kernel = kernel
        if let storage = kernel.storage {
            MenuBarHelperPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: LumiPluginLocalization.string("Menu Bar Manager", bundle: .module),
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

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(MenuBarHelperAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(MenuBarHelperManualView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
