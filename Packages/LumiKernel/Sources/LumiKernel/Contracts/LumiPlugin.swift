import Foundation
import SwiftUI

/// Lumi 插件协议
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
    var policy: LumiPluginPolicy { get }

    /// 插件分类
    ///
    /// 用于在插件管理界面分组与筛选。默认 `.general`。
    var category: LumiPluginCategory { get }

    /// 插件开发阶段
    ///
    /// 用于在管理界面以徽标提示成熟度。默认 `.stable`。
    var stage: LumiPluginStage { get }

    /// 插件描述
    ///
    /// 展示在插件管理界面列表与详情页。默认空字符串。
    /// 命名为 `pluginDescription` 以避免与 `CustomStringConvertible.description` 冲突。
    var pluginDescription: String { get }

    /// 阶段 1: 注入核心服务
    ///
    /// 在此方法中调用 `kernel.registerXxx()` 注册核心 Providing 实现，
    /// 以及注册工具、UI 贡献等所有需要内核提供的功能。
    func onBoot(kernel: LumiKernel) async throws

    /// 阶段 2: 所有服务就绪后执行异步初始化
    ///
    /// 在此方法中执行需要依赖其他服务的异步初始化逻辑。
    func onReady(kernel: LumiKernel) async throws

    // MARK: - LLM / Agent Contributions

    /// 提供 LLM Provider 实现
    func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider]

    /// 提供子 Agent 定义
    func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition]

    /// 提供 Agent 工具
    func agentTools(kernel: LumiKernel) -> [any LumiAgentTool]

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

    /// 设置标签项。已接入宿主 UI;插件可注册任意数量,会平铺显示在设置
    /// 侧边栏的内置标签(General / Appearance / About)之后。
    /// 应返回带稳定 `id` / `title` / `systemImage` 的项目,内容由 `makeContent()` 渲染。
    func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem]

    /// (当前未接入宿主 UI;保留 API 以备扩展。新插件建议使用 `settingsTabItems`。)
    func addSettingsView(kernel: LumiKernel) -> [AnyView]

    /// 插件关于视图。在由 `PluginManagerPlugin` 贡献的"插件管理"标签页的
    /// 每个插件详情面板中呈现;返回 `nil` 时显示空状态。
    func pluginAboutView(kernel: LumiKernel) -> AnyView?

    /// LLM Provider 设置项,已由 `LLMProviderManagerPlugin` 等路由器使用。
    func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem]

    /// LLM Provider 设置视图项(目前未被宿主 UI 渲染,保留供插件自查)。
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

    /// Agent Turn 结束后钩子
    func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async

    // MARK: - Workspace State

    /// 插件注册时调用，声明插件默认的工作区可见性偏好。
    func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility

    /// 容器激活时被回调
    func onContainerActivated(kernel: LumiKernel, containerID: String)

    // MARK: - Editor Extension

    /// 注册编辑器扩展
    func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async

    /// 配置编辑器运行时上下文
    func configureEditorRuntime(kernel: LumiKernel) async
}

// MARK: - Default Implementations

public extension LumiPlugin {
    /// LLM 发送前钩子的默认实现:不做任何修改,直接返回原 messages。
    /// 需要注入提示词的插件可重写此方法。
    @MainActor
    func willSendToLLM(kernel: LumiKernel, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        messages
    }

    /// Agent 工具的默认实现:不贡献任何工具。
    func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] { [] }

    /// 默认分类:通用。
    var category: LumiPluginCategory { .general }

    /// 默认阶段:稳定。
    var stage: LumiPluginStage { .stable }

    /// 默认描述:空字符串。
    var pluginDescription: String { "" }
}

