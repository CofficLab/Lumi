import LumiCoreAgentTool
import LumiCoreLayout
import LumiCoreLLMProvider
import LumiCoreMenuBar
import LumiCoreMessage
import LumiCoreOverlay
import LumiCorePanelChrome
import LumiCoreSubAgent
import SwiftUI

public protocol LumiPlugin {
    static var info: LumiPluginInfo { get }

    @MainActor
    static func titleToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiTitleToolbarItem]

    @MainActor
    static func statusBarItems(lumiCore: any LumiCoreAccessing) -> [LumiStatusBarItem]

    @MainActor
    static func viewContainers(lumiCore: any LumiCoreAccessing) -> [LumiViewContainerItem]

    @MainActor
    static func menuBarContentItems(lumiCore: any LumiCoreAccessing) -> [LumiMenuBarContentItem]

    @MainActor
    static func menuBarPopupItems(lumiCore: any LumiCoreAccessing) -> [LumiMenuBarPopupItem]

    @MainActor
    static func llmProviders(lumiCore: any LumiCoreAccessing) -> [any LumiLLMProvider]

    /// 收集插件提供的 Agent 工具。
    ///
    /// 允许 `throws`：插件在产出工具时若依赖外部资源（配置、凭证、SDK 初始化等）
    /// 失败，应抛错而不是静默返回空数组。聚合层（`LumiPluginRegistry.agentTools`）
    /// 会逐插件捕获异常并累积到失败列表，最终在「设置 → 插件」详情页展示给用户，
    /// 单个插件失败不影响其他插件的工具注册。
    @MainActor
    static func agentTools(lumiCore: any LumiCoreAccessing) throws -> [any LumiAgentTool]

    @MainActor
    static func subAgents(lumiCore: any LumiCoreAccessing) -> [LumiSubAgentDefinition]

    @MainActor
    static func sendMiddlewares(lumiCore: any LumiCoreAccessing) -> [any LumiSendMiddleware]

    @MainActor
    static func messageRenderers(lumiCore: any LumiCoreAccessing) -> [LumiMessageRendererItem]

    @MainActor
    static func addSettingsView(lumiCore: any LumiCoreAccessing) -> [AnyView]

    @MainActor
    static func addSettingsTabs(lumiCore: any LumiCoreAccessing) -> [LumiSettingsTabItem]

    /// 插件在“设置 → 插件”管理面板右侧的「关于」详情。
    @MainActor
    static func pluginAboutView(lumiCore: any LumiCoreAccessing) -> AnyView?

    @MainActor
    static func llmProviderSettingsViews(lumiCore: any LumiCoreAccessing) -> [LumiLLMProviderSettingsViewItem]

    @MainActor
    static func rootOverlays(lumiCore: any LumiCoreAccessing) -> [LumiRootOverlayItem]

    @MainActor
    static func onboardingPages(lumiCore: any LumiCoreAccessing) -> [AnyView]

    @MainActor
    static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem]

    @MainActor
    static func chatSectionToolbarBarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarBarItem]

    @MainActor
    static func chatSectionHeaderItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionHeaderItem]

    @MainActor
    static func chatSectionRootWrapper(lumiCore: any LumiCoreAccessing, content: AnyView) -> AnyView

    @MainActor
    static func chatSectionToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarItem]

    @MainActor
    static func panelHeaderItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelHeaderItem]

    @MainActor
    static func panelBottomTabItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelBottomTabItem]

    @MainActor
    static func panelRailTabItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelRailTabItem]

    @MainActor
    static func logoItems(lumiCore: any LumiCoreAccessing) -> [LogoItem]

    // MARK: - Lifecycle

    /// 插件生命周期事件
    ///
    /// 允许 `throws`：插件在 `.didRegister` / `.appDidLaunch` 里初始化数据库、读取配置、
    /// 加载外部 SDK 等可能失败的操作时，应抛错而不是静默降级（典型如 in-memory 降级会
    /// 导致“数据不落盘但用户无感”）。聚合层（`LumiPluginRegistry.registerAll` /
    /// `appDidLaunch`）会逐插件捕获并累积到失败列表，启动期失败经
    /// `bootstrapAfterPluginLifecycle` 走 CrashedView。
    @MainActor
    static func lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing) throws

    /// Agent Turn 结束后钩子（可选实现）
    ///
    /// 当一次 agent turn 结束时被调用，无论 turn 是成功完成、失败还是被取消。
    /// 适合用于清理状态、检查任务进度、触发自动续聊等场景。
    ///
    /// - Parameters:
    ///   - lumiCore: 内核访问入口
    ///   - conversationID: 会话 ID
    ///   - reason: turn 结束原因
    @MainActor
    static func onTurnFinished(lumiCore: any LumiCoreAccessing, conversationID: UUID, reason: LumiTurnEndReason) async

    // MARK: - Editor Extension (Optional)

    /// 注册编辑器扩展（语言支持、LSP 等）。可选实现。
    @MainActor
    static func registerEditorExtensions(into registry: AnyObject) async

    /// 配置编辑器运行时上下文。可选实现。
    @MainActor
    static func configureEditorRuntime(lumiCore: any LumiCoreAccessing) async
}

// MARK: - Tool Execution Hook

/// 允许插件在工具执行后介入处理。
///
/// 实现此协议的插件可以在工具执行完成后检查结果，
/// 并根据需要暂停 Agent 循环等待用户输入（例如 ask_user 等待用户回答）。
@MainActor
public protocol LumiToolExecutionHook {
    /// 工具执行完成后调用
    ///
    /// - Parameters:
    ///   - toolName: 工具名称
    ///   - result: 工具执行结果内容
    ///   - conversationID: 会话 ID
    /// - Returns: 是否需要暂停 Agent 循环等待用户输入。返回 `true` 后内核会
    ///   把 turn 结束原因设为 `.awaitingUserResponse`。
    static func handleToolResult(
        toolName: String,
        result: String,
        conversationID: UUID
    ) async -> Bool
}

// MARK: - Lifecycle Event

public enum LumiPluginLifecycle {
    case didRegister      // 插件注册时
    case appDidLaunch     // 应用启动
    case willDisable      // 插件即将被禁用时

    /// 用于日志与失败上报的可读标签。
    public var label: String {
        switch self {
        case .didRegister: return "didRegister"
        case .appDidLaunch: return "appDidLaunch"
        case .willDisable: return "willDisable"
        }
    }
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
    static func titleToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiTitleToolbarItem] {
        []
    }

    @MainActor
    static func statusBarItems(lumiCore: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        []
    }

    @MainActor
    static func viewContainers(lumiCore: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        []
    }

    @MainActor
    static func menuBarContentItems(lumiCore: any LumiCoreAccessing) -> [LumiMenuBarContentItem] {
        []
    }

    @MainActor
    static func menuBarPopupItems(lumiCore: any LumiCoreAccessing) -> [LumiMenuBarPopupItem] {
        []
    }

    @MainActor
    static func llmProviders(lumiCore: any LumiCoreAccessing) -> [any LumiLLMProvider] {
        []
    }

    @MainActor
    static func agentTools(lumiCore: any LumiCoreAccessing) throws -> [any LumiAgentTool] {
        []
    }

    @MainActor
    static func subAgents(lumiCore: any LumiCoreAccessing) -> [LumiSubAgentDefinition] {
        []
    }

    @MainActor
    static func sendMiddlewares(lumiCore: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        []
    }

    @MainActor
    static func messageRenderers(lumiCore: any LumiCoreAccessing) -> [LumiMessageRendererItem] {
        []
    }

    @MainActor
    static func addSettingsView(lumiCore: any LumiCoreAccessing) -> [AnyView] {
        []
    }

    @MainActor
    static func pluginAboutView(lumiCore: any LumiCoreAccessing) -> AnyView? {
        nil
    }

    @MainActor
    static func addSettingsTabs(lumiCore: any LumiCoreAccessing) -> [LumiSettingsTabItem] {
        []
    }

    @MainActor
    static func llmProviderSettingsViews(lumiCore: any LumiCoreAccessing) -> [LumiLLMProviderSettingsViewItem] {
        []
    }

    @MainActor
    static func rootOverlays(lumiCore: any LumiCoreAccessing) -> [LumiRootOverlayItem] {
        []
    }

    @MainActor
    static func onboardingPages(lumiCore: any LumiCoreAccessing) -> [AnyView] {
        []
    }

    @MainActor
    static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        []
    }

    @MainActor
    static func chatSectionToolbarBarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarBarItem] {
        []
    }

    @MainActor
    static func chatSectionHeaderItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionHeaderItem] {
        []
    }

    @MainActor
    static func chatSectionRootWrapper(lumiCore: any LumiCoreAccessing, content: AnyView) -> AnyView {
        content
    }

    @MainActor
    static func chatSectionToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionToolbarItem] {
        []
    }

    @MainActor
    static func panelHeaderItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelHeaderItem] {
        []
    }

    @MainActor
    static func panelBottomTabItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelBottomTabItem] {
        []
    }

    @MainActor
    static func panelRailTabItems(lumiCore: any LumiCoreAccessing) -> [LumiPanelRailTabItem] {
        []
    }

    @MainActor
    static func logoItems(lumiCore: any LumiCoreAccessing) -> [LogoItem] {
        []
    }

    // MARK: - Lifecycle Default Implementation

    @MainActor
    static func lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing) throws {}

    // MARK: - Turn Finished Hook Default Implementation

    @MainActor
    static func onTurnFinished(lumiCore: any LumiCoreAccessing, conversationID: UUID, reason: LumiTurnEndReason) async {}

    // MARK: - Editor Extension Default Implementations

    @MainActor
    static func registerEditorExtensions(into registry: AnyObject) async {}

    @MainActor
    static func configureEditorRuntime(lumiCore: any LumiCoreAccessing) async {}
}
