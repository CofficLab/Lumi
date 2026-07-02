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
    static func logoItems(context: LumiPluginContext) -> [LumiCore.LumiLogoItem]

    // MARK: - Lifecycle

    /// 插件生命周期事件
    @MainActor
    static func lifecycle(_ event: LumiPluginLifecycle)

    // MARK: - Editor Extension (Optional)

    /// 注册编辑器扩展（语言支持、LSP 等）。可选实现。
    @MainActor
    static func registerEditorExtensions(into registry: AnyObject) async

    /// 配置编辑器运行时上下文。可选实现。
    @MainActor
    static func configureEditorRuntime(_ context: PluginRuntimeContext) async
}

// MARK: - Lifecycle Event

public enum LumiPluginLifecycle {
    case didRegister      // 插件注册时
    case appDidLaunch     // 应用启动
    case projectDidOpen(path: String)  // 项目打开时
    case projectDidClose  // 项目关闭时
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
    static func logoItems(context: LumiPluginContext) -> [LumiCore.LumiLogoItem] {
        []
    }

    // MARK: - Lifecycle Default Implementation

    @MainActor
    static func lifecycle(_ event: LumiPluginLifecycle) {}

    // MARK: - Editor Extension Default Implementations

    @MainActor
    static func registerEditorExtensions(into registry: AnyObject) async {}

    @MainActor
    static func configureEditorRuntime(_ context: PluginRuntimeContext) async {}
}
