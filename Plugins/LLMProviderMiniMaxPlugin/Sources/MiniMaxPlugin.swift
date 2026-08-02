import LLMKit
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class MiniMaxPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.llm-provider.minimax"
    public let name = "MiniMax"
    public let order = 104
    public let policy: LumiPluginPolicy = .alwaysOn
    public var category: LumiPluginCategory { .llmProvider }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {}

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        [MiniMaxTokenPlanProvider(apiService: LLMAPIService(kernel: kernel))]
    }

    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        [
            StatusBarItem(
                id: "\(id).token-plan",
                title: "MiniMax Token Plan",
                systemImage: "chart.bar.fill",
                placement: .trailing,
                statusBarView: {
                    MiniMaxStatusBarVisibilityView(kernel: kernel)
                }
            )
        ]
    }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
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
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        let apiKeyProvider: @Sendable () -> String? = {
            APIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: "DevAssistant_ApiKey_MiniMax")
        }
        if let network = kernel.network {
            let client = MiniMaxVideoClient(network: network, apiKeyProvider: apiKeyProvider)
            return [MiniMaxVideoTool(client: client)]
        } else {
            // 网络能力未注册时,降级到普通 HTTPClient（理论上不会发生）
            let client = MiniMaxVideoClient(apiKeyProvider: apiKeyProvider)
            return [MiniMaxVideoTool(client: client)]
        }
    }
}
