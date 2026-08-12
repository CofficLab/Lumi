import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class PromoDesignerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-store-promo-designer"
    public var name: String { PromoLocalization.string("App Store Promo Designer") }
    public let order = 80
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        PromoLocalization.string("Agent-generated HTML promotional artwork with exact App Store export sizes.")
    }

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        try await PromoDesignerOnBootHook().execute(kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        try await PromoDesignerOnReadyHook().execute(kernel)
    }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            ListPromoTasksTool(),
            CreatePromoTaskTool(),
            ReadPromoTaskTool(),
            CreatePromoImageTool(),
            AddPromoImageLocalizationTool(),
            ReadPromoHTMLTool(),
            ReplacePromoHTMLTool(),
            PatchPromoHTMLTool(),
            ImportPromoAssetTool(),
            PreviewPromoImageTool(),
            LintPromoTaskTool(),
            ExportPromoTaskTool(),
            ReviewPromoImageTool(),
        ]
    }

    public func willSendToLLM(kernel: LumiKernel, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await PromoDesignerWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "app-store-promo.tasks",
                title: PromoLocalization.string("Promo Tasks"),
                systemImage: "photo.stack",
                visibility: .viewContainer(id: id)
            ) {
                PromoRailView()
            },
        ]
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "photo.artframe",
                supportsProject: true,
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                PromoDesignerView()
            },
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(PromoAboutView())
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: name,
                placement: .center,
                order: 0
            ) {
                PromoDesignerToolbarTitleView(containerID: self.id, kernel: kernel, title: self.name)
            },
        ]
    }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        if containerID == id { WorkspaceStore.shared.reload() }
    }
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
