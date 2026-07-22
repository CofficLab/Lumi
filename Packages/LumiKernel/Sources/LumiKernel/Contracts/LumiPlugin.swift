import Foundation




import SwiftUI

/// Lumi 插件协议
///
/// 所有插件必须实现此协议,以便向 LumiKernel 注册服务和 UI 贡献。
/// LumiKernel 持有所有服务（通过服务表），插件通过 `kernel` 参数访问其他服务（如 LumiCoreProviding）。
@MainActor
public protocol LumiPlugin: AnyObject {
    /// 插件唯一标识
    var id: String { get }

    /// 插件名称
    var name: String { get }

    /// 插件加载顺序
    ///
    /// 数值越小越先加载。用于控制插件间的依赖关系。
    /// - 核心插件：0-99
    /// - 基础服务：100-199
    /// - 功能插件：200-299
    /// - 可选插件：300+
    var order: Int { get }

    /// 插件启用策略
    ///
    /// 定义插件的启用行为和用户可配置性。
    /// - alwaysOn: 始终启用,不可禁用（如核心插件）
    /// - optOut: 默认启用,用户可禁用
    /// - optIn: 默认禁用,用户可启用
    /// - disabled: 禁用,不可启用
    var policy: LumiPluginPolicy { get }

    /// 阶段 1: 注入核心服务
    ///
    /// 在此方法中调用 `kernel.registerXxx()` 注册核心 Providing 实现。
    /// 按 order 顺序调用，order 小的插件先注入，后续插件可以依赖前面的服务。
    /// - Parameter kernel: LumiKernel 实例
    func onBoot(kernel: LumiKernel) throws

    /// 阶段 2: 所有服务就绪后注册功能
    ///
    /// 所有插件的 onBoot 完成后调用，此时所有核心服务都已可用。
    /// 在此方法中注册工具、UI 贡献等需要依赖其他服务的功能。
    /// - Parameter kernel: LumiKernel 实例
    func onReady(kernel: LumiKernel) throws

    /// 启动后回调（可选）
    ///
    /// 所有插件 onReady 完成后调用，用于执行异步初始化逻辑。
    /// - Parameter kernel: LumiKernel 实例
    func boot(kernel: LumiKernel) async throws

    // MARK: - LLM / Agent Contributions

    /// 提供 LLM Provider 实现
    func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider]

    /// 提供子 Agent 定义
    func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition]

    /// 提供发送中间件
    func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware]

    /// 提供消息渲染器
    func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem]

    // MARK: - Menu Bar / Title Bar Contributions

    /// 提供菜单栏内容项
    func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem]

    /// 提供菜单栏弹窗项
    func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem]

    /// 提供标题工具栏项
    func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem]

    // MARK: - Panel / Status Bar Contributions

    /// 面板顶部标题栏项
    func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem]

    /// 面板底部标签项
    func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem]

    /// 侧边栏标签项
    func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem]

    /// 状态栏项
    func statusBarItems(kernel: LumiKernel) -> [StatusBarItem]

    /// 视图容器项
    func viewContainers(kernel: LumiKernel) -> [ViewContainerItem]

    // MARK: - Chat Section Contributions

    /// 聊天分区项
    func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem]

    /// 聊天分区工具栏项
    func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem]

    /// 聊天分区工具栏条
    func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem]

    /// 聊天分区标题项
    func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem]

    /// 聊天分区动作栏项
    func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem]

    /// 聊天分区根视图包装器
    func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView

    // MARK: - Settings Contributions

    /// 设置标签项
    func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem]

    /// 在设置标签里加入视图
    func addSettingsView(kernel: LumiKernel) -> [AnyView]

    /// 插件关于视图
    func pluginAboutView(kernel: LumiKernel) -> AnyView?

    /// LLM Provider 设置项
    func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem]

    /// LLM Provider 设置视图项
    func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem]

    // MARK: - Overlay Contributions

    /// 根覆盖层项（Onboarding 等）
    func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem]

    /// 引导页项
    func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem]

    // MARK: - Logo Contributions

    /// Logo 项
    func logoItems(kernel: LumiKernel) -> [LogoItem]

    // MARK: - Lifecycle

    /// 生命周期事件
    /// 允许 `throws`：插件在 `.didRegister` / `.appDidLaunch` 里初始化数据库、读取配置、
    /// 加载外部 SDK 等可能失败的操作时,应抛错而不是静默降级。
    func lifecycle(_ event: LumiPluginLifecycle, kernel: LumiKernel) throws

    /// Agent Turn 结束后钩子（可选实现）
    ///
    /// 当一次 agent turn 结束时被调用,无论 turn 是成功完成、失败还是被取消。
    /// 适合用于清理状态、检查任务进度、触发自动续聊等场景。
    /// - Parameters:
    ///   - kernel: LumiKernel 实例
    ///   - conversationID: 会话 ID
    ///   - reason: turn 结束原因
    func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async

    // MARK: - Workspace State (Optional)

    /// 插件注册时调用，声明插件默认的工作区可见性偏好。
    /// - Parameter kernel: LumiKernel 实例
    /// - Returns: 可见性偏好；nil 字段表示不修改
    func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility

    /// 容器激活时被回调。插件可在此调整工作区状态以反映自身需要。
    /// - Parameters:
    ///   - kernel: LumiKernel 实例
    ///   - containerID: 刚被激活的容器 ID
    func onContainerActivated(kernel: LumiKernel, containerID: String)

    // MARK: - Editor Extension (Optional)

    /// 注册编辑器扩展（语言支持、LSP 等）。可选实现。
    func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async

    /// 配置编辑器运行时上下文。可选实现。
    func configureEditorRuntime(kernel: LumiKernel) async
}

// MARK: - Default Implementations

public extension LumiPlugin {
    /// 默认启用策略：默认启用,用户可禁用
    var policy: LumiPluginPolicy {
        .optOut
    }

    /// 默认 onBoot 实现：空操作
    func onBoot(kernel: LumiKernel) throws {}

    /// 默认 onReady 实现：空操作
    func onReady(kernel: LumiKernel) throws {}

    func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] {
        []
    }

    func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] {
        []
    }

    func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] {
        []
    }

    func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] {
        []
    }

    func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] {
        []
    }

    func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] {
        []
    }

    func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        []
    }

    func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] {
        []
    }

    func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] {
        []
    }

    func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        []
    }

    func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        []
    }

    func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        []
    }

    func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        []
    }

    func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] {
        []
    }

    func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] {
        []
    }

    func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] {
        []
    }

    func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] {
        []
    }

    func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView {
        content
    }

    func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] {
        []
    }

    func addSettingsView(kernel: LumiKernel) -> [AnyView] {
        []
    }

    func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        nil
    }

    func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] {
        []
    }

    func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] {
        []
    }

    func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] {
        []
    }

    func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] {
        []
    }

    func logoItems(kernel: LumiKernel) -> [LogoItem] {
        []
    }

    // MARK: - Lifecycle Default Implementation

    func lifecycle(_ event: LumiPluginLifecycle, kernel: LumiKernel) throws {}

    // MARK: - Turn Finished Hook Default Implementation

    func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}

    // MARK: - Workspace State Default Implementations

    func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility {
        WorkspaceVisibility()
    }

    func onContainerActivated(kernel: LumiKernel, containerID: String) {}

    // MARK: - Editor Extension Default Implementations

    func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}

    func configureEditorRuntime(kernel: LumiKernel) async {}
}

// MARK: - Tool Execution Hook

/// 允许插件在工具执行后介入处理。
///
/// 实现此协议的插件可以在工具执行完成后检查结果,
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
    func handleToolResult(
        toolName: String,
        result: String,
        conversationID: UUID
    ) async -> Bool
}

// MARK: - Lifecycle Event

public enum LumiPluginLifecycle {
    case didRegister      // 插件注册时
    case appDidLaunch     // 应用启动
    case projectDidOpen(path: String)  // 项目打开时
    case projectDidClose  // 项目关闭时
    case willDisable      // 插件即将被禁用时

    /// 用于日志与失败上报的可读标签。
    public var label: String {
        switch self {
        case .didRegister: return "didRegister"
        case .appDidLaunch: return "appDidLaunch"
        case .projectDidOpen: return "projectDidOpen"
        case .projectDidClose: return "projectDidClose"
        case .willDisable: return "willDisable"
        }
    }
}
