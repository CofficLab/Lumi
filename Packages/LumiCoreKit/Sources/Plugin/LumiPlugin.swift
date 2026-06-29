import SwiftUI

public protocol LumiPlugin {
    static var info: LumiPluginInfo { get }
    static var policy: LumiPluginPolicy { get }
    static var category: LumiPluginCategory { get }
    static var stage: LumiPluginStage { get }
    static var iconName: String { get }

    @MainActor
    static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem]

    @MainActor
    static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem]

    @MainActor
    static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem]

    @MainActor
    static func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem]

    @MainActor
    static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem]

    @MainActor
    static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider]

    @MainActor
    static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool]

    @MainActor
    static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware]

    @MainActor
    static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem]

    @MainActor
    static func aboutView(context: LumiPluginContext) -> AnyView?

    @MainActor
    static func addSettingsView(context: LumiPluginContext) -> [AnyView]

    @MainActor
    static func addSettingsTabs(context: LumiPluginContext) -> [LumiSettingsTabItem]

    @MainActor
    static func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem]

    @MainActor
    static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem]

    @MainActor
    static func onboardingPages(context: LumiPluginContext) -> [LumiPluginOnboardingPage]

    @MainActor
    static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem]

    @MainActor
    static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem]

    @MainActor
    static func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem]

    @MainActor
    static func chatSectionRootWrapper(context: LumiPluginContext, content: AnyView) -> AnyView

    @MainActor
    static func chatSectionToolbarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarItem]

    @MainActor
    static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem]

    @MainActor
    static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem]

    @MainActor
    static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem]

    @MainActor
    static func logoItems(context: LumiPluginContext) -> [LumiLogoItem]
}

public extension LumiPlugin {
    static var category: LumiPluginCategory {
        .general
    }

    static var stage: LumiPluginStage {
        .beta
    }

    static var iconName: String {
        "puzzlepiece.extension"
    }

    @MainActor
    static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        []
    }

    @MainActor
    static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        []
    }

    @MainActor
    static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        []
    }

    @MainActor
    static func menuBarContentItems(context: LumiPluginContext) -> [LumiMenuBarContentItem] {
        []
    }

    @MainActor
    static func menuBarPopupItems(context: LumiPluginContext) -> [LumiMenuBarPopupItem] {
        []
    }

    @MainActor
    static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        []
    }

    @MainActor
    static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        []
    }

    @MainActor
    static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        []
    }

    @MainActor
    static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        []
    }

    @MainActor
    static func aboutView(context: LumiPluginContext) -> AnyView? {
        nil
    }

    @MainActor
    static func addSettingsView(context: LumiPluginContext) -> [AnyView] {
        []
    }

    @MainActor
    static func addSettingsTabs(context: LumiPluginContext) -> [LumiSettingsTabItem] {
        []
    }

    @MainActor
    static func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem] {
        []
    }

    @MainActor
    static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        []
    }

    @MainActor
    static func onboardingPages(context: LumiPluginContext) -> [LumiPluginOnboardingPage] {
        []
    }

    @MainActor
    static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        []
    }

    @MainActor
    static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        []
    }

    @MainActor
    static func chatSectionHeaderItems(context: LumiPluginContext) -> [LumiChatSectionHeaderItem] {
        []
    }

    @MainActor
    static func chatSectionRootWrapper(context: LumiPluginContext, content: AnyView) -> AnyView {
        content
    }

    @MainActor
    static func chatSectionToolbarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarItem] {
        []
    }

    @MainActor
    static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        []
    }

    @MainActor
    static func panelBottomTabItems(context: LumiPluginContext) -> [LumiPanelBottomTabItem] {
        []
    }

    @MainActor
    static func panelRailTabItems(context: LumiPluginContext) -> [LumiPanelRailTabItem] {
        []
    }

    @MainActor
    static func logoItems(context: LumiPluginContext) -> [LumiLogoItem] {
        []
    }
}
