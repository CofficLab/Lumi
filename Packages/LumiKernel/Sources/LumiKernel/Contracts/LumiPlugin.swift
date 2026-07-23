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

