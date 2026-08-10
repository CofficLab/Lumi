import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class AppStorePromoDesignerPlugin: LumiPlugin {
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
        AppStorePromoRuntime.configure(kernel: kernel)
        AppStorePromoWorkspaceStore.shared.reload()
    }

    public func onReady(kernel: LumiKernel) async throws {}

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
        [
            ListAppStorePromoTasksTool(),
            CreateAppStorePromoTaskTool(),
            ReadAppStorePromoTaskTool(),
            CreateAppStorePromoImageTool(),
            ReadAppStorePromoHTMLTool(),
            ReplaceAppStorePromoHTMLTool(),
            PatchAppStorePromoHTMLTool(),
            ImportAppStorePromoAssetTool(),
            PreviewAppStorePromoImageTool(),
            LintAppStorePromoTaskTool(),
            ExportAppStorePromoTaskTool(),
        ]
    }

    public func willSendToLLM(kernel: LumiKernel, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }
        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: """
            App Store Promo Designer manages its own task library. For every user request such as "create promotional images for my app", first call app_store_promo_create_task exactly once, then create all requested artwork as multiple images under that task with app_store_promo_create_image. Each image is a complete deterministic HTML document. Import local assets with app_store_promo_import_asset, reference only returned relative paths, and never use remote resources, scripts, iframes, animations, or external fonts. Use responsive CSS so one image works at every display type in its device family. After each meaningful edit, call app_store_promo_preview_image and inspect its attached PNG. Source HTML and assets stay in plugin-managed storage; export only when the user selects an output directory.
            """
        )
        return [guidance] + messages
    }

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "app-store-promo.tasks",
                title: PromoLocalization.string("Promo Tasks"),
                systemImage: "photo.stack",
                visibility: .viewContainer(id: id)
            ) {
                AppStorePromoRailView()
            },
        ]
    }

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "photo.artframe",
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBodyVisibility: .alwaysVisible,
                panelBottomVisibility: .unsupported
            ) {
                AppStorePromoDesignerView()
            },
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(AppStorePromoAboutView())
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
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
        if containerID == id { AppStorePromoWorkspaceStore.shared.reload() }
    }
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
