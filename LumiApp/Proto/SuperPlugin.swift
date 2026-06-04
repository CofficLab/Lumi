import AppKit
import AgentToolKit
import EditorService
import Foundation
import SwiftUI
import LumiCoreKit

/// Rail 标签页定义
///
/// 插件通过 `addRailTabs()` 返回此结构体，由内核聚合渲染为统一的 Tab Bar。
struct RailTab: Identifiable, Equatable {
    /// 唯一标识
    let id: String
    /// 显示标题
    let title: String
    /// SF Symbol 图标名
    let systemImage: String
    /// 排序优先级（数字越小越靠前）
    let priority: Int

    static func == (lhs: RailTab, rhs: RailTab) -> Bool {
        lhs.id == rhs.id
    }
}

/// 右侧栏底部工具栏项定义
///
/// 插件通过 `addSidebarLeadingToolbarItems()` 或 `addSidebarTrailingToolbarItems()` 返回此结构体，
/// 由内核聚合渲染为右侧栏底部的水平工具栏。
/// 每个工具栏项通常由插件通过 `addSidebarToolbarItemView()` 提供完整可交互视图。
/// `SidebarToolbarItem` 本身只携带展示元数据，不携带点击动作。
struct SidebarToolbarItem: Identifiable, Equatable {
    /// 唯一标识
    let id: String
    /// 显示标题（用于 tooltip / accessibility）
    let title: String
    /// SF Symbol 图标名
    let systemImage: String
    /// 排序优先级（数字越小越靠左）
    let priority: Int

    static func == (lhs: SidebarToolbarItem, rhs: SidebarToolbarItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// 底部面板标签页定义
///
/// 插件通过 `addBottomPanelTabs()` 返回此结构体，由内核聚合渲染为统一的底部面板 Tab Bar。
/// 每个插件只需提供 Tab 入口和对应的内容视图，内核负责 Tab 栏渲染和切换。
struct BottomPanelTab: Identifiable, Equatable {
    /// 唯一标识
    let id: String
    /// 显示标题
    let title: String
    /// SF Symbol 图标名
    let systemImage: String
    /// 排序优先级（数字越小越靠前）
    let priority: Int

    static func == (lhs: BottomPanelTab, rhs: BottomPanelTab) -> Bool {
        lhs.id == rhs.id
    }
}

/// Activity Bar 视图容器定义
///
/// 插件通过 `addViewContainer()` 返回此结构体，由内核渲染 Activity Bar 入口，
/// 并在入口激活时延迟创建对应的面板视图。
struct ViewContainerItem: Identifiable, Equatable {
    /// 唯一标识
    let id: String
    /// 显示标题
    let title: String
    /// SF Symbol 图标名
    let icon: String
    /// 延迟创建视图
    let makeView: @MainActor () -> AnyView
    /// 是否在工具栏显示项目管理控件
    let showsProjectToolbar: Bool
    /// 是否支持 AI 聊天
    ///
    /// 当此容器处于激活状态时，聊天相关插件（消息列表、输入框、附件等）
    /// 会在右侧栏贡献各自的 Section 视图。
    /// 设为 `true` 的容器（如编辑器、聊天面板）表示其工作流与 AI 聊天紧密相关。
    let supportsAIChat: Bool
    /// 是否显示 Rail
    let showsRail: Bool
    /// 是否显示底部面板
    let showsBottomPanel: Bool

    init(
        id: String,
        title: String,
        icon: String,
        showsProjectToolbar: Bool = false,
        supportsAIChat: Bool = false,
        showsRail: Bool = false,
        showsBottomPanel: Bool = false,
        makeView: @escaping @MainActor () -> AnyView
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.showsProjectToolbar = showsProjectToolbar
        self.supportsAIChat = supportsAIChat
        self.showsRail = showsRail
        self.showsBottomPanel = showsBottomPanel
        self.makeView = makeView
    }

    static func == (lhs: ViewContainerItem, rhs: ViewContainerItem) -> Bool {
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
/// ## 插件类型
///
/// Lumi 支持以下类型的插件扩展点：
/// - 面板视图（活动栏入口，插件自行决定布局）
/// - 右侧栏视图（窗口右侧独立区域，可多插件堆叠）
/// - 菜单栏视图
/// - 底部状态栏视图
/// - 工具栏视图
/// - 设置视图
/// - Agent 工具与中间件
/// - 主题贡献
/// - 编辑器能力（补全、hover、code action、LSP 等），通过 `registerEditorExtensions` 注入
///
/// ## 使用示例
///
/// ```swift
/// actor MyPlugin: SuperPlugin {
///     static let id = "MyPlugin"
///     static let displayName = "我的插件"
///     static let iconName = "star.fill"
///     static let enabledByDefault = true
///     static let order = 100
///     static var isConfigurable: Bool { true }
/// }
/// ```
protocol SuperPlugin: Actor {
    /// 插件共享实例。
    ///
    /// AppPluginVM 的自动发现阶段通过类型暴露的共享实例拿到插件，
    /// 避免使用 ObjC Runtime 的 `alloc/init` 或给 Actor 增加同步构造约束。
    static var shared: Self { get }

    // MARK: - Core Properties

    /// 插件唯一标识符
    ///
    /// 用于在插件系统中唯一识别插件。建议使用有意义的英文标识符，
    /// 默认实现会自动从类名中提取（去掉 "Plugin" 后缀）。
    static var id: String { get }

    /// 插件显示名称
    ///
    /// 将显示在 UI 的各个位置，如设置面板、导航项等。
    /// 建议使用用户友好的中文或英文名称。
    static var displayName: String { get }

    /// 插件描述
    ///
    /// 简短描述插件的功能，用于设置面板中的插件说明。
    static var description: String { get }

    /// 插件描述（按语言偏好）
    ///
    /// 新插件应优先实现该方法以提供多语言描述；旧插件会通过默认实现回退到
    /// ``description``，从而保持源码兼容。
    static func description(for language: LanguagePreference) -> String

    /// 插件图标名称
    ///
    /// SF Symbols 图标名称，将显示在导航栏、设置面板等位置。
    /// 建议使用与插件功能相关的 SF Symbols 图标。
    static var iconName: String { get }

    /// 插件注册策略，统一控制注册 / 启用 / 可配置行为
    static var policy: PluginPolicy { get }

    /// 是否可配置（从 policy 派生，新代码请直接使用 policy）
    static var isConfigurable: Bool { get }

    /// 是否启用此插件（已废弃，请使用 policy）
    @available(*, deprecated, message: "Use policy instead. This property will be removed in a future version.")
    static var enable: Bool { get }

    /// 插件是否应该被注册到插件系统（从 policy 派生）
    static var shouldRegister: Bool { get }

    /// 插件默认是否启用（从 policy 派生）
    static var enabledByDefault: Bool { get }

    /// 插件实例标签（用于识别唯一实例）
    ///
    /// 用于在插件列表中区分不同实例。在单插件场景下通常返回 `Self.id`。
    /// 如果一个插件类型可能有多个实例，可重写此属性返回唯一标识。
    nonisolated var instanceLabel: String { get }

    /// 插件实例级元数据。
    ///
    /// 默认从静态属性派生；type-erased bridge 可覆盖这些值，以保留 package
    /// 插件的真实类型信息。
    nonisolated var pluginID: String { get }
    nonisolated var pluginDisplayName: String { get }
    nonisolated var pluginDescription: String { get }
    nonisolated var pluginIconName: String { get }
    nonisolated var pluginPolicy: PluginPolicy { get }
    nonisolated var pluginCategory: PluginCategory { get }
    nonisolated var pluginOrder: Int { get }
    nonisolated func pluginDescription(for language: LanguagePreference) -> String

    // MARK: - View Methods

    /// 添加根视图包裹
    ///
    /// 允许插件包裹整个应用的内容视图，实现全局拦截、修饰等功能。
    /// 此方法在视图层次的最外层执行，可以用于：
    /// - 添加全局 overlay
    /// - 拦截手势事件
    /// - 应用全局样式
    ///
    /// - Parameter content: 要被包裹的原始内容视图
    /// - Returns: 包裹后的视图，如果不需要则返回 nil
    ///
    /// ## 注意
    ///
    /// 多个插件的根视图包裹会按照插件注册顺序依次执行，
    /// 外层包裹先执行，内层包裹后执行。
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View

    /// 包裹右侧栏根视图
    ///
    /// 允许插件只包裹右侧栏内容，用于右侧栏范围内的拖放检测、浮层提示等能力。
    /// 插件之间仍通过窗口级 VM 交换状态，避免具体插件互相持有引用。
    ///
    /// - Parameters:
    ///   - content: 右侧栏原始内容。
    ///   - context: 插件视图构建上下文，包含当前激活 ViewContainer 的能力信息。
    /// - Returns: 包裹后的右侧栏内容。
    @MainActor func wrapRightSidebarRoot(_ content: AnyView, context: PluginContext) -> AnyView

    /// 添加工具栏前导视图
    /// - Parameter context: 插件视图构建上下文
    @MainActor func addToolBarLeadingView(context: PluginContext) -> AnyView?

    /// 添加工具栏中间视图
    /// - Parameter context: 插件视图构建上下文
    @MainActor func addToolBarCenterView(context: PluginContext) -> AnyView?

    /// 添加工具栏右侧视图
    /// - Parameter context: 插件视图构建上下文
    @MainActor func addToolBarTrailingView(context: PluginContext) -> AnyView?

    /// 添加 Activity Bar 视图容器
    ///
    /// 提供一个在左侧活动栏中注册的入口及其对应面板视图。插件自行决定视图的布局方式，
    /// 例如只读列表、可交互的管理界面、或者编辑器等。
    /// 点击活动栏图标后，该容器视图会在左侧面板或中间栏中展示。
    @MainActor func addViewContainer() -> ViewContainerItem?

    /// 提供 Panel Header 视图
    ///
    /// 在面板内容区上方渲染的头部视图。多个插件提供的 header 视图
    /// 会按插件 `order` 升序垂直堆叠（order 小的在上，大的在下）。
    ///
    /// 典型用例：编辑器的 Tab Strip、面包屑导航等。
    ///
    /// - Parameter context: 插件视图构建上下文。
    ///   插件应将其 `activeIcon` 与目标 view container 的 `icon` 比较，
    ///   仅在匹配时提供 header 视图。
    @MainActor func addPanelHeaderView(context: PluginContext) -> AnyView?

    /// 提供底部面板标签页列表
    ///
    /// 插件返回一个或多个 `BottomPanelTab`，由内核聚合渲染为统一的底部面板 Tab Bar。
    /// 每个 tab 包含 id、标题、图标和排序优先级。
    /// 内核负责 Tab 栏渲染和切换，插件只需提供 Tab 入口。
    ///
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab]

    /// 提供指定底部面板 Tab 对应的内容视图
    ///
    /// 内核在用户选中某个 Tab 时调用此方法获取对应的内容视图。
    ///
    /// - Parameter tabId: 选中的 tab id，与 `addBottomPanelTabs()` 返回的 `BottomPanelTab.id` 对应。
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView?

    /// 提供 Rail 标签页列表
    ///
    /// 插件返回一个或多个 `RailTab`，由内核聚合渲染为统一的 Tab Bar。
    /// 每个 tab 包含 id、标题、图标和排序优先级。
    ///
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addRailTabs(context: PluginContext) -> [RailTab]

    /// 提供指定 Rail tab 对应的内容视图
    ///
    /// 内核在用户选中某个 tab 时调用此方法获取对应的内容视图。
    ///
    /// - Parameter tabId: 选中的 tab id，与 `addRailTabs()` 返回的 `RailTab.id` 对应。
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addRailContentView(tabId: String, context: PluginContext) -> AnyView?

    /// 添加右侧栏 Section 视图
    ///
    /// 插件通过此方法提供一个或多个 Section 视图，由内核使用 VStack 垂直堆叠
    /// 在窗口右侧栏中。每个 Section 独立贡献一块 UI 区域（如消息列表、输入框等）。
    ///
    /// 多个插件的 Sections 按插件 `order` 升序排列（order 小的在上，大的在下）；
    /// 同一插件内的多个 Sections 按数组顺序排列。
    ///
    /// - Parameter context: 插件视图构建上下文。
    ///   插件可从 context 中读取当前 ViewContainer 的能力声明
    ///   （如 `supportsAIChat`、`showsProjectToolbar`），决定是否贡献右侧栏 Section。
    ///
    /// 典型用例：聊天消息列表、输入区域、预览面板、属性检查器等。
    @MainActor func addSidebarSections(context: PluginContext) -> [AnyView]

    /// 添加固定在右侧栏底部的 Section 视图
    ///
    /// 适合输入框这类必须始终可见的区域。内核会把这些 Section 放在普通
    /// Section 之后、底部工具栏之前，不参与上方消息列表的弹性高度分配。
    @MainActor func addSidebarBottomSections(context: PluginContext) -> [AnyView]

    /// 提供右侧栏底部工具栏左侧项列表
    ///
    /// 插件返回一个或多个 `SidebarToolbarItem`，由内核聚合渲染到右侧栏底部工具栏左侧。
    /// 每个工具栏项按 `priority` 升序排列，交互由 `addSidebarToolbarItemView()` 提供。
    ///
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem]

    /// 提供右侧栏底部工具栏右侧项列表
    ///
    /// 插件返回一个或多个 `SidebarToolbarItem`，由内核聚合渲染到右侧栏底部工具栏右侧。
    /// 每个工具栏项按 `priority` 升序排列。
    ///
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addSidebarTrailingToolbarItems(context: PluginContext) -> [SidebarToolbarItem]

    /// 提供指定右侧栏工具栏项对应的自定义按钮视图
    ///
    /// 内核在渲染工具栏时，优先使用此方法返回的自定义视图作为按钮内容。
    /// 如果返回 nil，内核会使用 `SidebarToolbarItem` 的 `systemImage` 渲染非交互占位图标。
    ///
    /// - Parameter itemId: 工具栏项 id，与 leading/trailing toolbar items 返回的 `SidebarToolbarItem.id` 对应。
    /// - Parameter context: 插件视图构建上下文。
    @MainActor func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView?

    /// 添加设置视图
    @MainActor func addSettingsView() -> AnyView?

    /// 添加插件海报视图列表
    ///
    /// 海报视图展示在「设置 - 插件管理」的插件行下方，用于说明插件功能、
    /// 入口位置或贡献的 UI 区域。一个插件可以返回多个海报视图。
    @MainActor func addPosterViews() -> [AnyView]

    /// 添加菜单栏弹窗视图列表
    ///
    /// 返回该插件提供的所有菜单栏弹窗视图。支持一个插件注册多个弹窗。
    /// 多个弹窗会在菜单栏弹窗中垂直堆叠显示。
    @MainActor func addMenuBarPopupViews() -> [AnyView]

    /// 添加菜单栏弹窗视图（向后兼容，默认返回单个视图包装为数组）
    ///
    /// - Returns: 菜单栏弹窗视图，如果不需要则返回 nil
    /// 新插件应优先实现 `addMenuBarPopupViews()`；该入口保留给只提供单个弹窗的旧插件。
    @MainActor func addMenuBarPopupView() -> AnyView?

    /// 添加菜单栏内容视图
    @MainActor func addMenuBarContentView() -> AnyView?

    /// 添加状态栏左侧视图
    /// - Parameter context: 插件视图构建上下文
    @MainActor func addStatusBarLeadingView(context: PluginContext) -> AnyView?

    /// 添加状态栏中间视图
    /// - Parameter context: 插件视图构建上下文
    @MainActor func addStatusBarCenterView(context: PluginContext) -> AnyView?

    /// 添加状态栏右侧视图
    /// - Parameter context: 插件视图构建上下文
    @MainActor func addStatusBarTrailingView(context: PluginContext) -> AnyView?

    /// 提供主题贡献（App + Editor 一体化主题）。
    @MainActor func addThemeContributions() -> [LumiUIThemeContribution]

    // MARK: - Agent Tools Hooks

    /// 提供 Agent 工具列表（可按需使用 `context` 注入依赖）。
    @MainActor func agentTools(context: ToolContext) -> [SuperAgentTool]

    /// 提供内核级子 Agent 定义列表。
    @MainActor func subAgentDefinitions() -> [any SubAgentDefinitionProtocol]

    // MARK: - Send Pipeline

    /// 提供「用户消息入队 → 发送模型」管线中间件（按插件 `order` 与中间件 `order` 排序）。
    @MainActor func sendMiddlewares() -> [AnySuperSendMiddleware]

    /// 插件提供的 LLM 供应商类型
    ///
    /// 如果插件是一个 LLM 供应商插件，返回对应的 `SuperLLMProvider.Type`。
    /// `AppPluginVM` 会在插件注册阶段自动收集并注册到 `LLMProviderRegistry`。
    /// 默认返回 `nil`，表示该插件不提供 LLM 供应商。
    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)?

    /// 插件提供的消息渲染器列表
    ///
    /// 如果插件提供自定义消息渲染器，返回 `SuperMessageRenderer` 实例数组。
    /// `AppPluginVM` 会在插件注册阶段自动收集并注册到 `AppMessageRendererVM`。
    /// 默认返回空数组，表示该插件不提供消息渲染器。
    @MainActor func messageRenderers() -> [any SuperMessageRenderer]

    // MARK: - Editor Extension Points

    /// 标记该插件是否提供编辑器扩展能力
    ///
    /// 返回 `true` 表示该插件会向 `EditorExtensionRegistry` 注入编辑器能力
    ///（如补全、hover、code action、LSP 服务等）。
    /// `AppPluginVM` 会据此过滤出编辑器插件，交给 `EditorExtensionRegistry` 安装。
    /// 默认返回 `false`。
    nonisolated var providesEditorExtensions: Bool { get }

    /// 向编辑器扩展注册中心注入能力
    ///
    /// 当插件的 `providesEditorExtensions` 为 `true` 时，此方法会被调用。
    /// 插件在此方法中向 `EditorExtensionRegistry` 注册其提供的编辑器能力，例如：
    /// - `registerCompletionContributor` — 代码补全
    /// - `registerHoverContributor` — 悬浮提示
    /// - `registerCodeActionContributor` — 快速修复
    /// - `registerCommandContributor` — 编辑器命令
    /// - 其他扩展点
    ///
    /// 默认实现为空操作。只有需要贡献编辑器能力的插件才需要重写此方法。
    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry)

    // MARK: - Lifecycle Hooks

    /// 插件注册完成后的回调
    nonisolated func onRegister()

    /// 插件被启用时的回调
    nonisolated func onEnable()

    /// 插件被禁用时的回调
    nonisolated func onDisable()

    /// 插件分类
    ///
    /// 用于在插件设置等 UI 中按分类分组展示。
    /// **必须提供**，每个插件都必须明确指定自己的功能分类。
    static var category: PluginCategory { get }

    /// 插件注册顺序（数字越小越先加载）
    static var order: Int { get }
}

// MARK: - Default Implementation

extension SuperPlugin {
    /// 自动派生插件 ID（类名去掉 "Plugin" 后缀）
    static var id: String {
        String(describing: self)
            .replacingOccurrences(of: "Plugin", with: "")
    }

    nonisolated var instanceLabel: String { Self.id }

    nonisolated var pluginID: String { Self.id }

    nonisolated var pluginDisplayName: String { Self.displayName }

    nonisolated var pluginDescription: String { Self.description }

    nonisolated var pluginIconName: String { Self.iconName }

    nonisolated var pluginPolicy: PluginPolicy { Self.policy }

    nonisolated var pluginCategory: PluginCategory { Self.category }

    nonisolated var pluginOrder: Int { Self.order }

    nonisolated func pluginDescription(for language: LanguagePreference) -> String {
        Self.description(for: language)
    }

    nonisolated var pluginEnabledByDefault: Bool {
        switch pluginPolicy {
        case .alwaysOn, .optOut: return true
        case .optIn, .disabled: return false
        }
    }

    nonisolated var pluginIsConfigurable: Bool {
        switch pluginPolicy {
        case .alwaysOn, .disabled: return false
        case .optIn, .optOut: return true
        }
    }

    static var displayName: String { id }

    static var description: String { "" }

    static func description(for language: LanguagePreference) -> String {
        description
    }

    static var iconName: String { "puzzlepiece" }

    // 注意：category 必须由每个插件显式提供，不再有默认值

    static var isConfigurable: Bool {
        switch policy {
        case .alwaysOn, .disabled: return false
        case .optOut, .optIn: return true
        }
    }

    @available(*, deprecated, message: "Use policy instead.")
    static var enable: Bool { enabledByDefault }

    static var shouldRegister: Bool { policy != .disabled }

    static var enabledByDefault: Bool {
        switch policy {
        case .alwaysOn, .optOut: return true
        case .optIn, .disabled: return false
        }
    }
}
