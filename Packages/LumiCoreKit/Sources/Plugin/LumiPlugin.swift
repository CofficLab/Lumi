import SwiftUI

public protocol LumiPlugin {
    static var info: LumiPluginInfo { get }

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
    static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition]

    @MainActor
    static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware]

    @MainActor
    static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem]

    @MainActor
    static func addSettingsView(context: LumiPluginContext) -> [AnyView]

    @MainActor
    static func addSettingsTabs(context: LumiPluginContext) -> [LumiSettingsTabItem]

    /// 插件在“设置 → 插件”管理面板右侧的「关于」详情。
    ///
    /// 与 `addSettingsView` 的语义区别：
    /// - `addSettingsView`：插件向外部设置容器贡献内容
    ///   （聚合到其他设置页，例如 LLM 设置、模型选择）。
    /// - `pluginAboutView`：插件**关于自己**的描述，**只**展示在
    ///   「设置 → 插件 → 选中此插件」时的右侧详情面板。
    ///
    /// 推荐内容：长描述、README/文档链接、版本号、作者、数据来源、隐私说明等
    /// "看广告"信息。**不要**放功能开关与可配置项——那些请通过 `addSettingsTabs`
    /// 单独成为设置面板的一项。
    ///
    /// 默认实现返回 `nil`，详情面板会展示"该插件未提供详细信息"的占位。
    @MainActor
    static func pluginAboutView(context: LumiPluginContext) -> AnyView?

    @MainActor
    static func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem]

    @MainActor
    static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem]

    @MainActor
    static func onboardingPages(context: LumiPluginContext) -> [AnyView]

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
    static func logoItems(context: LumiPluginContext) -> [LogoItem]

    // MARK: - Lifecycle

    /// 插件生命周期事件
    @MainActor
    static func lifecycle(_ event: LumiPluginLifecycle)

    /// Agent Turn 结束后钩子（可选实现）
    ///
    /// 当一次 agent turn 结束时被调用，无论 turn 是成功完成、失败还是被取消。
    /// 适合用于清理状态、检查任务进度、触发自动续聊等场景。
    ///
    /// - Parameters:
    ///   - context: 插件上下文
    ///   - conversationID: 会话 ID
    ///   - reason: turn 结束原因
    @MainActor
    static func onTurnFinished(context: LumiPluginContext, conversationID: UUID, reason: LumiTurnEndReason) async

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
    case willDisable      // 插件即将被禁用时
}

public extension LumiPlugin {
    /// 插件分类，派生自 `info.category`
    static var category: LumiPluginCategory {
        info.category
    }

    /// 启用策略，派生自 `info.policy`
    static var policy: LumiPluginPolicy {
        info.policy
    }

    /// 开发阶段，派生自 `info.stage`
    static var stage: LumiPluginStage {
        info.stage
    }

    /// SF Symbols 图标名称，派生自 `info.iconName`
    static var iconName: String {
        info.iconName
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
    static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
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
    static func pluginAboutView(context: LumiPluginContext) -> AnyView? {
        nil
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
    static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
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
    static func logoItems(context: LumiPluginContext) -> [LogoItem] {
        []
    }

    // MARK: - Lifecycle Default Implementation

    @MainActor
    static func lifecycle(_ event: LumiPluginLifecycle) {}

    // MARK: - Turn Finished Hook Default Implementation

    @MainActor
    static func onTurnFinished(context: LumiPluginContext, conversationID: UUID, reason: LumiTurnEndReason) async {}

    // MARK: - Editor Extension Default Implementations

    @MainActor
    static func registerEditorExtensions(into registry: AnyObject) async {}

    @MainActor
    static func configureEditorRuntime(_ context: PluginRuntimeContext) async {}
}
