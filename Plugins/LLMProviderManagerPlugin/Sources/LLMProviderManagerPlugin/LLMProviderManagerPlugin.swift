import Foundation
import LumiKernel
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

    public func onBoot(kernel: LumiKernel) async throws {
        let service = LLMProviderManager()
        service.kernel = kernel
        try kernel.registerLLMProviderService(service)
        self.manager = service
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 LLMProviderManager 到内核")
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        #if DEBUG
            [MockLLMProvider()]
        #else
            []
        #endif
    }

    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        [
            ProviderAPIKeyMissingRenderer.item(kernel: kernel),
            ProviderAPIKeyAccessFailedRenderer.item(kernel: kernel),
        ]
    }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }

    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
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

    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Label(LumiPluginLocalization.string("LLM Provider Manager", bundle: .module),
                      systemImage: "list.bullet")
                    .font(.headline)
                Text(LumiPluginLocalization.string("LLM provider for chat and agent conversations.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
