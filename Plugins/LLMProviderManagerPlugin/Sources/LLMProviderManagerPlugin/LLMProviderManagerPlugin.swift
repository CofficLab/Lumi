import Foundation
import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// LLM Provider Manager Plugin
@MainActor
public final class LLMProviderManagerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider-manager")
    public nonisolated static let emoji = "🧠"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.llm-provider-manager"
    public var name: String {
        LumiPluginLocalization.string("LLM Provider Manager", bundle: .module)
    }
    public let order = 10
    public let policy: LumiPluginPolicy = .alwaysOn // 核心插件
    public let stage: LumiPluginStage = .beta

    private var manager: LLMProviderManager?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        let service = LLMProviderManager()
        service.kernel = kernel
        try kernel.registerLLMProviderService(service)
        self.manager = service
        for configuration in CustomProviderStore.shared.load() {
            try? service.registerCustomProvider(configuration)
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 LLMProviderManager 到内核")
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] {
        #if DEBUG
            [MockLLMProvider()]
        #else
            []
        #endif
    }

    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] {
        [
            ProviderAPIKeyMissingRenderer.item(kernel: kernel),
            ProviderAPIKeyAccessFailedRenderer.item(kernel: kernel),
        ]
    }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        return [
            SettingsTabItem(
                id: "\(id).remote-providers",
                title: LumiPluginLocalization.string("Cloud Providers", bundle: .module),
                systemImage: "cloud",
                order: 100
            ) {
                AnyView(RemoteProviderSettingsPage(kernel: kernel))
            },
            SettingsTabItem(
                id: "\(id).local-providers",
                title: LumiPluginLocalization.string("Local Providers", bundle: .module),
                systemImage: "cpu",
                order: 101
            ) {
                AnyView(LocalProviderSettingsPage(kernel: kernel))
            },
        ]
    }

    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(
            LLMProviderLandingPage(displayName: LumiPluginLocalization.string("LLM Provider Manager", bundle: .module), icon: "list.bullet")
        )
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
