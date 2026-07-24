import LLMProviderManagerPlugin
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ModelSelectorPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.model-selector"
    public let name = "Model Selector"
    public let order = 82
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}
    public func onReady(kernel: LumiKernel) async throws {}

    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] {
        guard let lumiCore = kernel.lumiCore,
              let chatService = lumiCore.resolveService((any LumiChatServicing).self) else {
            return []
        }

        let availability = kernel.resolveService((any LumiLLMProviderSettingsContributing).self)
            .map { $0 as? LLMProviderManager }
            .flatMap { $0?.providerAvailabilityState }

        return [
            ChatSectionToolbarItem(id: "\(id).picker", placement: .leading) {
                ModelProviderPicker(
                    chatService: chatService,
                    availability: availability
                )
            },
        ]
    }

    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] {
        guard let lumiCore = kernel.lumiCore,
              let chatService = lumiCore.resolveService((any LumiChatServicing).self) else {
            return []
        }

        return [
            ChatSectionToolbarBarItem(id: "\(id).tps") {
                CurrentModelTPSToolbarView(chatService: chatService)
            },
        ]
    }

    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        guard let llmProvider = kernel.resolveService((any LLMProviderManaging).self) else {
            return []
        }
        let conversationManaging = kernel.resolveService((any ConversationManaging).self)

        return [
            ChatSectionActionBarItem(id: "\(id).action-bar-button", placement: .trailing) {
                ModelSelectorActionBarButton(
                    llmProvider: llmProvider,
                    conversationManaging: conversationManaging
                )
            },
        ]
    }

    public func agentTools(kernel: LumiKernel) -> [LumiAgentTool] {
        guard let lumiCore = kernel.lumiCore,
              let chatService = lumiCore.resolveService((any LumiChatServicing).self) else {
            return []
        }
        return [
            SwitchModelTool(chatService: chatService),
            CheckModelAvailabilityTool(chatService: chatService),
            ListAvailableModelsTool(chatService: chatService),
        ]
    }

    /// Settings tabs (Local / Cloud Providers) 已迁到 `LLMProviderManagerPlugin`。
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
