import SwiftUI

public protocol LumiPlugin {
    static var info: LumiPluginInfo { get }
    static var policy: LumiPluginPolicy { get }
    static var category: LumiPluginCategory { get }
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
    static func settingsDetailView(context: LumiPluginContext) -> AnyView?

    @MainActor
    static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem]
}

public extension LumiPlugin {
    static var category: LumiPluginCategory {
        .general
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
    static func settingsDetailView(context: LumiPluginContext) -> AnyView? {
        nil
    }

    @MainActor
    static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        []
    }
}
