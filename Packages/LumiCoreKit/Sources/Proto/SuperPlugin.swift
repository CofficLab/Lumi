import AppKit
import AgentToolKit
import Foundation
import LumiUI
import SwiftUI

/// Rail 标签页定义
///
/// 插件通过 `addRailTabs()` 返回此结构体，由内核聚合渲染为统一的 Tab Bar。
public struct RailTab: Identifiable, Equatable {
    /// 唯一标识
    public let id: String
    /// 显示标题
    public let title: String
    /// SF Symbol 图标名
    public let systemImage: String
    /// 排序优先级（数字越小越靠前）
    public let priority: Int

    public init(id: String, title: String, systemImage: String, priority: Int) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
    }

    public static func == (lhs: RailTab, rhs: RailTab) -> Bool {
        lhs.id == rhs.id
    }
}

/// 右侧栏底部工具栏项定义
public struct SidebarToolbarItem: Identifiable, Equatable {
    /// 唯一标识
    public let id: String
    /// 显示标题（用于 tooltip / accessibility）
    public let title: String
    /// SF Symbol 图标名
    public let systemImage: String
    /// 排序优先级（数字越小越靠左）
    public let priority: Int

    public init(id: String, title: String, systemImage: String, priority: Int) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
    }

    public static func == (lhs: SidebarToolbarItem, rhs: SidebarToolbarItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 底部面板标签页定义
public struct BottomPanelTab: Identifiable, Equatable {
    /// 唯一标识
    public let id: String
    /// 显示标题
    public let title: String
    /// SF Symbol 图标名
    public let systemImage: String
    /// 排序优先级（数字越小越靠前）
    public let priority: Int

    public init(id: String, title: String, systemImage: String, priority: Int) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
    }

    public static func == (lhs: BottomPanelTab, rhs: BottomPanelTab) -> Bool {
        lhs.id == rhs.id
    }
}

/// Activity Bar 视图容器定义
///
/// 插件通过 `addViewContainer()` 返回此结构体，由内核渲染 Activity Bar 入口，
/// 并在入口激活时延迟创建对应的面板视图。
public struct ViewContainerItem: Identifiable, Equatable {
    /// 唯一标识
    public let id: String
    /// 显示标题
    public let title: String
    /// SF Symbol 图标名
    public let icon: String
    /// 延迟创建视图
    public let makeView: @MainActor () -> AnyView
    /// 是否在工具栏显示项目管理控件
    ///
    /// 当此容器处于激活状态时，ProjectsPlugin 会在工具栏中间显示项目选择器。
    /// 设为 `true` 的容器（如编辑器、Git）表示其工作流与项目上下文紧密相关。
    public let showsProjectToolbar: Bool

    /// 是否支持 AI 聊天
    ///
    /// 当此容器处于激活状态时，聊天相关插件（消息列表、输入框、附件等）
    /// 会在右侧栏贡献各自的 Section 视图。
    /// 设为 `true` 的容器（如编辑器、聊天面板）表示其工作流与 AI 聊天紧密相关。
    public let supportsAIChat: Bool

    /// 是否显示 Rail
    ///
    /// 当此容器处于激活状态时，Rail 插件会在 Rail 栏注册对应标签页。
    /// 设为 `true` 的容器（如编辑器）表示其工作流需要侧栏辅助区域。
    public let showsRail: Bool

    public init(
        id: String,
        title: String,
        icon: String,
        showsProjectToolbar: Bool = false,
        supportsAIChat: Bool = false,
        showsRail: Bool = false,
        makeView: @escaping @MainActor () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.showsProjectToolbar = showsProjectToolbar
        self.supportsAIChat = supportsAIChat
        self.showsRail = showsRail
        self.makeView = makeView
    }

    public static func == (lhs: ViewContainerItem, rhs: ViewContainerItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 插件协议，定义插件的基本接口和 UI 贡献方法
///
/// SuperPlugin 是 Lumi 插件系统的核心协议，所有插件都必须实现此协议。
/// 该协议采用 Actor 模式以确保线程安全，允许插件在后台执行耗时操作。
///
/// ## 插件生命周期
///
/// 1. **注册阶段**: 插件被自动发现并实例化，调用 `onRegister()`
/// 2. **启用阶段**: 插件被添加到 UI 树，调用 `onEnable()`
/// 3. **禁用阶段**: 插件从 UI 树移除，调用 `onDisable()`
///
/// ## 使用示例
///
/// ```swift
/// actor MyPlugin: SuperPlugin {
///     static let id = "MyPlugin"
///     static let displayName = "我的插件"
///     static let iconName = "star.fill"
///     static let enable = true
///     static let order = 100
///     static var isConfigurable: Bool { true }
/// }
/// ```
public protocol SuperPlugin: Actor {
    /// 插件共享实例。
    static var shared: Self { get }

    // MARK: - Core Properties

    /// 插件唯一标识符
    static var id: String { get }

    /// 插件显示名称
    static var displayName: String { get }

    /// 插件描述
    static var description: String { get }

    /// 插件描述（按语言偏好）
    ///
    /// 新插件应优先实现该方法以提供多语言描述；旧插件会通过默认实现回退到
    /// ``description``，从而保持源码兼容。
    static func description(for language: LanguagePreference) -> String

    /// 插件图标名称（SF Symbols）
    static var iconName: String { get }

    /// 插件注册策略，统一控制注册 / 启用 / 可配置行为
    static var policy: PluginPolicy { get }

    /// 是否可配置（从 policy 派生，新代码请直接使用 policy）
    static var isConfigurable: Bool { get }

    /// 是否启用此插件（已废弃，请使用 policy）
    @available(*, deprecated, message: "Use policy instead. This property will be removed in a future version.")
    static var enable: Bool { get }

    /// 是否应该注册此插件（从 policy 派生，新代码请直接使用 policy）
    static var shouldRegister: Bool { get }

    /// 默认启用状态（从 policy 派生，新代码请直接使用 policy）
    static var enabledByDefault: Bool { get }

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String { get }

    // MARK: - View Methods

    /// 添加根视图包裹
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View

    /// 包裹右侧栏根视图
    @MainActor func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView

    /// 添加工具栏前导视图
    @MainActor func addToolBarLeadingView(context: PluginContext) -> AnyView?

    /// 添加工具栏中间视图
    @MainActor func addToolBarCenterView(context: PluginContext) -> AnyView?

    /// 添加工具栏右侧视图
    @MainActor func addToolBarTrailingView(context: PluginContext) -> AnyView?

    /// 添加 Activity Bar 视图容器
    @MainActor func addViewContainer() -> ViewContainerItem?

    /// 提供 Panel Header 视图
    @MainActor func addPanelHeaderView(context: PluginContext) -> AnyView?

    /// 提供底部面板标签页列表
    @MainActor func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab]

    /// 提供指定底部面板 Tab 对应的内容视图
    @MainActor func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView?

    /// 提供 Rail 标签页列表
    @MainActor func addRailTabs(context: PluginContext) -> [RailTab]

    /// 提供指定 Rail tab 对应的内容视图
    @MainActor func addRailContentView(tabId: String, context: PluginContext) -> AnyView?

    /// 添加右侧栏 Section 视图
    @MainActor func addSidebarSections(context: PluginContext) -> [AnyView]

    /// 添加固定在右侧栏底部的 Section 视图
    @MainActor func addSidebarBottomSections(context: PluginContext) -> [AnyView]

    /// 提供右侧栏底部工具栏左侧项列表
    @MainActor func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem]

    /// 提供右侧栏底部工具栏右侧项列表
    @MainActor func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem]

    /// 提供指定右侧栏工具栏项对应的自定义按钮视图
    @MainActor func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView?

    /// 添加设置视图
    @MainActor func addSettingsView() -> AnyView?

    /// 添加插件海报视图列表
    ///
    /// 海报视图展示在「设置 - 插件管理」的插件行下方，用于说明插件功能、
    /// 入口位置或贡献的 UI 区域。一个插件可以返回多个海报视图。
    @MainActor func addPosterViews() -> [AnyView]

    /// 添加菜单栏弹窗视图列表
    @MainActor func addMenuBarPopupViews() -> [AnyView]

    /// 添加菜单栏弹窗视图（向后兼容）
    ///
    /// 新插件应优先实现 `addMenuBarPopupViews()`；该入口保留给只提供单个弹窗的旧插件。
    @MainActor func addMenuBarPopupView() -> AnyView?

    /// 添加菜单栏内容视图
    @MainActor func addMenuBarContentView() -> AnyView?

    /// 添加状态栏左侧视图
    @MainActor func addStatusBarLeadingView(context: PluginContext) -> AnyView?

    /// 添加状态栏中间视图
    @MainActor func addStatusBarCenterView(context: PluginContext) -> AnyView?

    /// 添加状态栏右侧视图
    @MainActor func addStatusBarTrailingView(context: PluginContext) -> AnyView?

    /// 提供主题贡献
    @MainActor func addThemeContributions() -> [LumiUIThemeContribution]

    // MARK: - Agent Tools Hooks

    /// 提供 Agent 工具列表
    @MainActor func agentTools(context: ToolContext) -> [SuperAgentTool]

    /// 提供内核级子 Agent 定义列表
    @MainActor func subAgentDefinitions() -> [any SubAgentDefinitionProtocol]

    // MARK: - Send Pipeline

    /// 提供「用户消息入队 → 发送模型」管线中间件
    @MainActor func sendMiddlewares() -> [AnySuperSendMiddleware]

    /// 插件提供的 LLM 供应商类型
    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)?

    /// 插件提供的消息渲染器列表
    @MainActor func messageRenderers() -> [any SuperMessageRenderer]

    // MARK: - Editor Extension Points

    /// 标记该插件是否提供编辑器扩展能力
    nonisolated var providesEditorExtensions: Bool { get }

    /// 向编辑器扩展注册中心注入能力
    @MainActor func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol)

    // MARK: - Lifecycle Hooks

    /// 插件注册完成后的回调
    nonisolated func onRegister()

    /// 插件被启用时的回调
    nonisolated func onEnable()

    /// 插件被禁用时的回调
    nonisolated func onDisable()

    /// 插件分类
    static var category: PluginCategory { get }

    /// 插件注册顺序（数字越小越先加载）
    static var order: Int { get }
}
