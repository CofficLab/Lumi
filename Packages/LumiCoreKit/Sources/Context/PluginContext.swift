import Foundation
import AgentToolKit
import SwiftUI

/// 插件视图构建上下文
///
/// 在插件构建视图时提供的上下文，承载当前 UI 状态信息。
/// LumiCoreKit 中定义最小化版本，内核在运行时注入完整实现。
///
/// ## 扩展指南
///
/// 当需要向插件传递更多上下文信息时，在此结构体中添加新属性即可。
/// 所有新增属性应提供合理的默认值，以保持向后兼容性。
@MainActor
public struct PluginContext {
    /// 当前激活的活动栏图标（SF Symbol 名称）
    ///
    /// 插件可以通过比较此值与自己的面板图标来决定是否提供视图。
    public let activeIcon: String?

    /// 编辑器是否可见
    ///
    /// 当编辑器未显示时（如纯 Agent 模式），依赖编辑器的插件可据此隐藏自身视图。
    public let isEditorVisible: Bool

    /// 当前活跃的 LLM 供应商 ID
    ///
    /// 优先取对话级偏好，无偏好时回退到全局选择。
    /// 供应商插件可据此决定是否展示供应商专属 UI（如配额状态栏）。
    public let activeProviderId: String?

    /// 当前激活的 ViewContainer 聊天区域显示模式
    ///
    /// 由 ViewContainerItem 的 `showChat` 属性投影而来。
    /// 聊天相关插件（消息列表、输入框、附件等）可据此决定是否贡献右侧栏 Section。
    public let showChat: ChatDisplayMode

    /// 当前激活的 ViewContainer 是否显示项目工具栏
    ///
    /// 由 ViewContainerItem 的 `showsProjectToolbar` 属性投影而来。
    /// 项目相关插件可据此决定是否贡献工具栏视图。
    public let showsProjectToolbar: Bool

    /// 当前激活的 ViewContainer 是否显示 Rail
    ///
    /// 由 ViewContainerItem 的 `showsRail` 属性投影而来。
    /// Rail 插件据此决定是否注册标签页。
    public let showsRail: Bool

    /// 当前激活的 ViewContainer 是否显示底部面板
    ///
    /// 由 ViewContainerItem 的 `showsBottomPanel` 属性投影而来。
    /// 底部面板插件据此决定是否注册标签页。
    public let showsBottomPanel: Bool

    /// 当前正在构建插件视图的窗口 ID。
    ///
    /// 多窗口插件贡献需要用它选择窗口级服务，避免进程级 bridge 误用其他窗口状态。
    public let windowId: UUID?

    /// 当前项目路径。
    ///
    /// 为空字符串表示当前窗口未选择项目。
    public let currentProjectPath: String

    /// 当前窗口的语言偏好。
    public let languagePreference: LanguagePreference

    /// 语言偏好读写能力（由内核注入）。
    ///
    /// 需要读写对话级语言设置的插件应优先使用这个显式 capability，
    /// 避免依赖宿主 SwiftUI 树中必须存在特定 `@EnvironmentObject`。
    public let languagePreferenceContext: LanguagePreferenceContext?

    /// 聊天模式读写能力（由内核注入）。
    ///
    /// 需要读写对话级 Chat/Build/Autonomous 偏好的插件应优先使用这个显式 capability。
    public let chatModePreferenceContext: ChatModePreferenceContext?

    /// 响应详细程度读写能力（由内核注入）。
    ///
    /// 需要读写对话级 verbosity 偏好的插件应优先使用这个显式 capability。
    public let verbosityPreferenceContext: VerbosityPreferenceContext?

    /// 聊天提交能力（由内核注入）。
    ///
    /// 右侧栏提交按钮通过此 capability 读取草稿并提交消息。
    public let chatSubmitContext: ChatSubmitContext?

    /// 新建会话能力（由内核注入）。
    ///
    /// 标题栏新建按钮通过此 capability 创建新会话。
    public let conversationCreationContext: ConversationCreationContext?

    /// 模型选择入口能力（由内核注入）。
    ///
    /// 模型选择 toolbar 入口通过此 capability 显示当前模型并打开选择视图。
    public let modelSelectionContext: ModelSelectionContext?

    /// 布局菜单控制能力（由内核注入）。
    ///
    /// 布局插件通过此 capability 读写可见性状态。
    public let layoutControlContext: LayoutControlContext?

    /// 当前运行时可用的 Agent 工具。
    public let availableTools: [SuperAgentTool]

    /// 工具描述展示使用的语言偏好。
    public let toolLanguagePreference: LanguagePreference

    /// 历史数据查询服务（由内核注入）。
    ///
    /// 插件通过此服务查询消息和对话历史，无需直接访问 SwiftData。
    /// 为 `nil` 时表示当前环境不支持历史查询（如测试或预览场景）。
    public let historyService: (any HistoryQueryService)?

    /// 对话列表能力（由内核注入）。
    ///
    /// 插件通过此对象读取、选择、创建和维护对话列表，不直接依赖 app 的 ViewModel。
    public let conversationListContext: ConversationListContext?

    /// 消息渲染能力（由内核注入）。
    ///
    /// 消息列表类插件通过此能力调用当前已注册的消息渲染器，不直接依赖 app 的渲染器 ViewModel。
    public let messageRenderer: (ChatMessage, Binding<Bool>) -> AnyView?

    public init(
        activeIcon: String? = nil,
        isEditorVisible: Bool = true,
        activeProviderId: String? = nil,
        showChat: ChatDisplayMode = .hidden,
        showsProjectToolbar: Bool = false,
        showsRail: Bool = false,
        showsBottomPanel: Bool = false,
        windowId: UUID? = nil,
        currentProjectPath: String = "",
        languagePreference: LanguagePreference = .current,
        languagePreferenceContext: LanguagePreferenceContext? = nil,
        chatModePreferenceContext: ChatModePreferenceContext? = nil,
        verbosityPreferenceContext: VerbosityPreferenceContext? = nil,
        chatSubmitContext: ChatSubmitContext? = nil,
        conversationCreationContext: ConversationCreationContext? = nil,
        modelSelectionContext: ModelSelectionContext? = nil,
        layoutControlContext: LayoutControlContext? = nil,
        availableTools: [SuperAgentTool] = [],
        toolLanguagePreference: LanguagePreference = .current,
        historyService: (any HistoryQueryService)? = nil,
        conversationListContext: ConversationListContext? = nil,
        messageRenderer: @escaping (ChatMessage, Binding<Bool>) -> AnyView? = { _, _ in nil }
    ) {
        self.activeIcon = activeIcon
        self.isEditorVisible = isEditorVisible
        self.activeProviderId = activeProviderId
        self.showChat = showChat
        self.showsProjectToolbar = showsProjectToolbar
        self.showsRail = showsRail
        self.showsBottomPanel = showsBottomPanel
        self.windowId = windowId
        self.currentProjectPath = currentProjectPath
        self.languagePreference = languagePreference
        self.languagePreferenceContext = languagePreferenceContext
        self.chatModePreferenceContext = chatModePreferenceContext
        self.verbosityPreferenceContext = verbosityPreferenceContext
        self.chatSubmitContext = chatSubmitContext
        self.conversationCreationContext = conversationCreationContext
        self.modelSelectionContext = modelSelectionContext
        self.layoutControlContext = layoutControlContext
        self.availableTools = availableTools
        self.toolLanguagePreference = toolLanguagePreference
        self.historyService = historyService
        self.conversationListContext = conversationListContext
        self.messageRenderer = messageRenderer
    }
}
