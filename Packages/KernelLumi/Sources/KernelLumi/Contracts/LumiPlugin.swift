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
    /// 用于在管理界面以徽标提示成熟度。**必须显式声明**。
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
    func onBoot(kernel: KernelLumi) async throws

    /// 阶段 2: 所有服务就绪后执行异步初始化
    ///
    /// 在此方法中执行需要依赖其他服务的异步初始化逻辑。
    func onReady(kernel: KernelLumi) async throws

    /// 运行时启用插件时调用。
    ///
    /// 这是与启动阶段 `onBoot` / `onReady` 分开的运行时生命周期；插件可以在这里
    /// 启动监听器、任务或其他只在用户启用后才需要的资源。
    func onEnable(kernel: KernelLumi) async throws

    /// 运行时禁用插件时调用。
    ///
    /// 插件应在这里释放由 `onEnable` 创建的运行时资源。贡献的 UI、工具和 Provider
    /// 会由 PluginManager 在生命周期回调完成后统一重建。
    func onDisable(kernel: KernelLumi) async throws

    // MARK: - LLM / Agent Contributions

    /// 提供 LLM Provider 实现
    func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider]

    /// 提供 Agent 工具
    func agentTools(kernel: KernelLumi) -> [any LumiAgentTool]

    /// LLM 发送前钩子。
    ///
    /// 插件可在 AgentTurnRunner 构造请求前修改消息列表,例如注入 system prompt。
    func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage]

    /// 提供消息渲染器
    func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem]

    // MARK: - Menu Bar / Title Bar Contributions

    /// 提供菜单栏内容项
    func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem]

    /// 提供菜单栏弹窗项
    func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem]

    /// 提供标题工具栏项
    func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem]

    // MARK: - Command Contributions

    /// 提供应用命令菜单组。
    ///
    /// 宿主根据 `CommandMenuGroup.placement` 将命令渲染到对应的 macOS 菜单位置。
    func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup]

    // MARK: - Panel / Status Bar Contributions

    /// 面板顶部标题栏项
    func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem]

    /// 面板底部标签项
    func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem]

    /// 侧边栏标签项
    func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem]

    /// 状态栏项
    func statusBarItems(kernel: KernelLumi) -> [StatusBarItem]

    /// 视图容器项
    func viewContainers(kernel: KernelLumi) -> [ViewContainerItem]

    // MARK: - Chat Section Contributions

    /// 聊天分区项
    func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem]

    /// 聊天分区工具栏项
    func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem]

    /// 聊天分区工具栏条
    func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem]

    /// 聊天分区标题项
    func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem]

    /// 聊天分区动作栏项
    func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem]

    /// 聊天分区根视图包装器
    func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView

    // MARK: - Prompt Suggestions

    /// 贡献聊天起始提示词。
    ///
    /// 插件返回的提示词由内核聚合（按插件 `order` 排序，同插件内保持返回顺序），
    /// 供空态等 UI 展示。点击提示词时通常把 `prompt` 写入输入框。
    /// `id` 需稳定唯一（建议带插件前缀，如 `"icon-designer.design"`）。
    ///
    /// - Important: 本方法必须是**纯声明式元数据**——只返回静态数据，不得依赖
    ///   `onBoot` / `onEnable` 注册的服务或副作用。内核在收集提示词时**不区分插件启用
    ///   状态**：即便插件当前禁用，其提示词也会被聚合（并标记 `requiresEnable = true`），
    ///   以便用户在空态点击时「启用并发送」。
    func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion]

    // MARK: - Web Server Contributions

    /// 贡献本地 Web 服务的 HTTP 路由。
    ///
    /// 内核会启动一个仅监听本地回环地址(127.0.0.1)的 Web 服务,聚合所有启用插件
    /// 贡献的路由,使用户(或其它本地工具)可通过 HTTP API 触发插件能力。
    ///
    /// 返回的 `WebRoute.handler` 运行在主线程上,可直接调用 `kernel` 上以
    /// `@MainActor` 暴露的服务(如 `kernel.theme`)。
    ///
    /// - Important: 路由 `id` 需稳定唯一并建议带插件前缀(如
    ///   `"theme-manager.switch"`)。当插件在运行时启用/禁用时,内核会按插件整体
    ///   替换其路由,无需插件手动处理生命周期。
    func webRoutes(kernel: KernelLumi) -> [WebRoute]

    // MARK: - Settings Contributions

    /// 设置标签项。已接入宿主 UI;插件可注册任意数量,会平铺显示在设置
    /// 侧边栏的内置标签(General / Appearance / About)之后。
    /// 应返回带稳定 `id` / `title` / `systemImage` 的项目,内容由 `makeContent()` 渲染。
    func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem]

    /// 设置页 section 项。挂载到指定 tab 的内容区（而非整页 tab）。
    /// 用于向其它插件提供的设置 tab 追加局部区块；返回的 section 需指定
    /// `tabID` 以挂载到目标 tab，内容由消费侧调用 `makeContent(context:)` 渲染。
    /// 若渲染依赖具体实体（如单个项目），消费侧会通过 `context` 传入其标识。
    func settingsSections(kernel: KernelLumi) -> [SettingsSection]

    /// (当前未接入宿主 UI;保留 API 以备扩展。新插件建议使用 `settingsTabItems`。)
    func addSettingsView(kernel: KernelLumi) -> [AnyView]

    /// 插件关于视图。在由 `PluginManagerPlugin` 贡献的"插件管理"标签页的
    /// 每个插件详情面板中呈现;返回 `nil` 时显示空状态。
    func pluginAboutView(kernel: KernelLumi) -> AnyView?

    /// 插件说明书视图。
    ///
    /// 与 `pluginAboutView` 类似的拉取式入口:插件可返回自己的使用说明 /
    /// 功能手册视图,供宿主的说明书 UI 在渲染时按需调用。返回 `nil` 表示
    /// 该插件没有提供说明书。默认返回 `nil`。
    func pluginManualView(kernel: KernelLumi) -> AnyView?

    /// LLM Provider 设置项,已由 `LLMProviderManagerPlugin` 等路由器使用。
    func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem]

    /// LLM Provider 设置视图项(目前未被宿主 UI 渲染,保留供插件自查)。
    func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem]

    // MARK: - Overlay Contributions

    /// 根覆盖层项（Onboarding 等）
    func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem]

    /// 引导页项
    func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem]

    // MARK: - Logo Contributions

    /// Logo 项
    func logoItems(kernel: KernelLumi) -> [LogoItem]

    // MARK: - Lifecycle

    /// Agent Turn 结束后钩子
    func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async

    // MARK: - Workspace State

    /// 容器激活时被回调
    func onContainerActivated(kernel: KernelLumi, containerID: String)

    // MARK: - External File Opening

    /// 外部文件打开请求（Finder 打开方式、Dock 拖入等）。
    ///
    /// 宿主在收到非项目目录的文件打开请求时，按启用顺序询问所有插件，
    /// 第一个返回 `true` 的插件接管该文件，后续插件不再收到通知。
    ///
    /// - Parameters:
    ///   - kernel: 内核
    ///   - url: 已确认存在的本地文件 URL（不会是目录）
    /// - Returns: 返回 `true` 表示该插件已接管此文件；返回 `false` 表示无法处理，交给下一个插件。
    func openFile(kernel: KernelLumi, url: URL) -> Bool

    // MARK: - Editor Extension

    /// 注册编辑器扩展
    func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async

    /// 配置编辑器运行时上下文
    func configureEditorRuntime(kernel: KernelLumi) async

    /// 提供编辑器运行时插件。
    ///
    /// 语言高亮、语法、语言描述等编辑器扩展应优先通过此 typed 贡献点接入。
    /// 插件只需要依赖 `KernelLumi` 的 `EditorPlugin` / `EditorExtensionRegistrar`
    /// 协议；具体编辑器宿主由 `EditorProviding` 在边界处桥接到运行时实现。
    func editorPlugins(kernel: KernelLumi) -> [any EditorPlugin]

    /// 编辑器贡献包（契约 V2，重构方案 §9.1）。
    ///
    /// 取代 `editorPlugins` / `registerEditorExtensions` / `configureEditorRuntime`
    /// 的最终贡献入口。Bundle 构建阶段只创建描述符和 Provider，
    /// **不得**启动 Language Server、watcher 或后台任务。
    /// Host 按插件维度原子安装/替换/撤回（`kernel.editorV2.extensions`）。
    func editorContributionBundle(kernel: KernelLumi) async throws -> EditorContributionBundle?
}

// MARK: - Default Implementations

public extension LumiPlugin {
    /// 默认没有额外的运行时启用逻辑。
    func onEnable(kernel: KernelLumi) async throws {}

    /// 默认没有额外的运行时禁用逻辑。
    func onDisable(kernel: KernelLumi) async throws {}

    /// LLM 发送前钩子的默认实现:不做任何修改,直接返回原 messages。
    /// 需要注入提示词的插件可重写此方法。
    @MainActor
    func willSendToLLM(kernel: KernelLumi, messages: [LumiChatMessage]) async -> [LumiChatMessage] {
        messages
    }

    /// Agent 工具的默认实现:不贡献任何工具。
    func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] { [] }

    /// 默认不贡献任何命令菜单组。
    func commandMenuGroups(kernel: KernelLumi) -> [CommandMenuGroup] { [] }

    /// 默认分类:通用。
    var category: LumiPluginCategory { .general }

    /// 默认描述:空字符串。
    var pluginDescription: String { "" }

    /// 默认不注册编辑器扩展。
    func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}

    /// 默认不配置编辑器运行时。
    func configureEditorRuntime(kernel: KernelLumi) async {}

    /// 默认不贡献编辑器运行时插件。
    func editorPlugins(kernel: KernelLumi) -> [any EditorPlugin] { [] }

    /// 默认不贡献编辑器贡献包。
    func editorContributionBundle(kernel: KernelLumi) async throws -> EditorContributionBundle? { nil }

    /// 默认不处理任何外部文件打开请求。
    func openFile(kernel: KernelLumi, url: URL) -> Bool { false }

    /// 默认不贡献任何设置 section。
    func settingsSections(kernel: KernelLumi) -> [SettingsSection] { [] }

    /// 默认不贡献任何聊天起始提示词。
    func promptSuggestions(kernel: KernelLumi) -> [LumiPromptSuggestion] { [] }

    /// 默认不贡献任何 Web 路由。
    func webRoutes(kernel: KernelLumi) -> [WebRoute] { [] }

    /// 默认不提供说明书视图。
    func pluginManualView(kernel: KernelLumi) -> AnyView? { nil }
}
