import KernelLumi
import LumiUI
import SwiftUI

@MainActor
public final class PromoDesignerPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.app-store-promo-designer"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "app-store-promo.tasks"

    public var name: String { PromoLocalization.string("App Store Promo Designer") }
    public let order = 80
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        PromoLocalization.string("Agent-generated HTML promotional artwork with exact App Store export sizes.")
    }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        try await PromoDesignerOnBootHook().execute(kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        try await PromoDesignerOnReadyHook().execute(kernel)
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
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

    public func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        await PromoDesignerWillSendToLLMHook().execute(kernel: kernel, messages: messages)
    }

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: PromoLocalization.string("Promo Tasks"),
                systemImage: "photo.stack",
                visibility: .viewContainer(id: id)
            ) {
                PromoRailView()
            },
        ]
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
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

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(PromoAboutView())
    }

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
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
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {
        if containerID == id { WorkspaceStore.shared.reload() }
    }
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
