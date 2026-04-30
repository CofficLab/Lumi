import AppKit
import SwiftUI
import Foundation

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
/// - 状态栏视图
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
///     static let enable = true
///     static let order = 100
///     static var isConfigurable: Bool { true }
/// }
/// ```
protocol SuperPlugin: Actor {
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

    /// 插件图标名称
    ///
    /// SF Symbols 图标名称，将显示在导航栏、设置面板等位置。
    /// 建议使用与插件功能相关的 SF Symbols 图标。
    static var iconName: String { get }

    /// 是否可配置
    ///
    /// 如果为 true，用户可以在设置中启用/禁用此插件。
    /// 如果为 false，插件始终处于启用状态。
    static var isConfigurable: Bool { get }

    /// 是否启用此插件
    ///
    /// 静态属性，控制插件的默认启用状态。
    /// 配合 `isConfigurable` 使用：
    /// - `isConfigurable = false`: 始终启用，忽略此值
    /// - `isConfigurable = true`: 使用此值作为默认值
    static var enable: Bool { get }

    /// 插件实例标签（用于识别唯一实例）
    ///
    /// 用于在插件列表中区分不同实例。在单插件场景下通常返回 `Self.id`。
    /// 如果一个插件类型可能有多个实例，可重写此属性返回唯一标识。
    nonisolated var instanceLabel: String { get }

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

    /// 添加工具栏前导视图
    /// - Parameter activeIcon: 当前被激活的 ActivityBar 图标名称
    @MainActor func addToolBarLeadingView(activeIcon: String?) -> AnyView?

    /// 添加工具栏中间视图
    /// - Parameter activeIcon: 当前被激活的 ActivityBar 图标名称
    @MainActor func addToolBarCenterView(activeIcon: String?) -> AnyView?

    /// 添加工具栏右侧视图
    /// - Parameter activeIcon: 当前被激活的 ActivityBar 图标名称
    @MainActor func addToolBarTrailingView(activeIcon: String?) -> AnyView?

    /// 提供面板图标（SF Symbol 名称）
    ///
    /// 用于在左侧活动栏中显示该插件的面板入口图标。
    /// 只有同时提供 `addPanelView()` 的插件才需要实现此方法。
    /// 返回 nil 表示使用插件默认的 `iconName`。
    ///
    /// ## 注意
    ///
    /// 此方法与 `addPanelView()` 配对使用：
    /// - `addPanelIcon()` 提供活动栏图标
    /// - `addPanelView()` 提供面板内容视图
    nonisolated func addPanelIcon() -> String?

    /// 添加面板视图
    ///
    /// 提供一个在左侧活动栏中注册的视图入口。插件自行决定视图的布局方式，
    /// 例如只读列表、可交互的管理界面、或者编辑器等。
    /// 点击活动栏图标后，该视图会在左侧面板或中间栏中展示。
    ///
    /// - Parameter activeIcon: 当前被激活的 ActivityBar 图标名称（SF Symbol）。
    ///   插件应将其与自己的 `addPanelIcon()` 返回值比较，匹配时才提供面板视图。
    ///   如果为 `nil`，表示没有任何图标被激活。
    @MainActor func addPanelView(activeIcon: String?) -> AnyView?

    /// 添加 Rail 视图
    ///
    /// 提供一个位于活动栏与面板内容区之间的辅助栏视图。
    /// Rail 适合放置上下文相关的辅助导航或浏览内容，
    /// 例如文件浏览器树、符号大纲、书签列表等。
    ///
    /// - Parameter activeIcon: 当前被激活的 ActivityBar 图标名称（SF Symbol）。
    ///   插件可据此判断是否提供 Rail 视图（例如仅在特定插件激活时显示）。
    ///
    /// ## 互斥规则
    ///
    /// ⚠️ 全局最多只能有一个插件提供 Rail 视图。
    /// 如果多个插件同时提供，会显示冲突错误视图。
    /// 请确保只有一个启用的插件实现了此方法。
    @MainActor func addRailView(activeIcon: String?) -> AnyView?

    /// 添加右侧栏视图
    ///
    /// 提供一个在窗口右侧显示的侧边栏视图。多个插件提供的侧边栏视图
    /// 会被水平堆叠，按插件的 `order` 升序排列（order 小的在左，大的在右）。
    /// 右侧栏与面板内容区之间支持拖拽调整宽度。
    ///
    /// - Parameter activeIcon: 当前被激活的 ActivityBar 图标名称（SF Symbol）。
    ///   插件可据此判断是否提供侧边栏视图（例如仅在特定插件激活时显示）。
    ///
    /// 典型用例：聊天栏、预览面板、属性检查器等。
    @MainActor func addSidebarView(activeIcon: String?) -> AnyView?

    /// 添加设置视图
    @MainActor func addSettingsView() -> AnyView?

    /// 添加状态栏弹窗视图列表
    ///
    /// 返回该插件提供的所有状态栏弹窗视图。支持一个插件注册多个弹窗。
    /// 多个弹窗会在状态栏弹窗中垂直堆叠显示。
    @MainActor func addStatusBarPopupViews() -> [AnyView]

    /// 添加状态栏弹窗视图（向后兼容，默认返回单个视图包装为数组）
    ///
    /// - Returns: 状态栏弹窗视图，如果不需要则返回 nil
    /// - Deprecated: 使用 `addStatusBarPopupViews()` 替代
    @available(*, deprecated, message: "Use addStatusBarPopupViews() returning [AnyView] instead")
    @MainActor func addStatusBarPopupView() -> AnyView?

    /// 添加状态栏内容视图
    @MainActor func addStatusBarContentView() -> AnyView?

    /// 添加状态栏左侧视图（用于 Agent 模式底部状态栏）
    @MainActor func addStatusBarLeadingView() -> AnyView?

    /// 添加状态栏中间视图（用于 Agent 模式底部状态栏）
    @MainActor func addStatusBarCenterView() -> AnyView?

    /// 添加状态栏右侧视图（用于 Agent 模式底部状态栏）
    @MainActor func addStatusBarTrailingView() -> AnyView?

    /// 提供主题贡献（App + Editor 一体化主题）。
    @MainActor func addThemeContributions() -> [LumiThemeContribution]

    // MARK: - Agent Tools Hooks

    /// 提供 Agent 工具列表。
    @MainActor func agentTools() -> [SuperAgentTool]

    /// 提供 Agent 工具工厂列表（带依赖注入）。
    @MainActor func agentToolFactories() -> [AnySuperAgentToolFactory]

    // MARK: - Send Pipeline

    /// 提供「用户消息入队 → 发送模型」管线中间件（按插件 `order` 与中间件 `order` 排序）。
    @MainActor func sendMiddlewares() -> [AnySuperSendMiddleware]

    /// 插件提供的 LLM 供应商类型
    ///
    /// 如果插件是一个 LLM 供应商插件，返回对应的 `SuperLLMProvider.Type`。
    /// `PluginVM` 会在插件注册阶段自动收集并注册到 `LLMProviderRegistry`。
    /// 默认返回 `nil`，表示该插件不提供 LLM 供应商。
    nonisolated func llmProviderType() -> (any SuperLLMProvider.Type)?

    /// 插件提供的消息渲染器列表
    ///
    /// 如果插件提供自定义消息渲染器，返回 `SuperMessageRenderer` 实例数组。
    /// `PluginVM` 会在插件注册阶段自动收集并注册到 `MessageRendererVM`。
    /// 默认返回空数组，表示该插件不提供消息渲染器。
    @MainActor func messageRenderers() -> [any SuperMessageRenderer]

    // MARK: - Editor Extension Points

    /// 标记该插件是否提供编辑器扩展能力
    ///
    /// 返回 `true` 表示该插件会向 `EditorExtensionRegistry` 注入编辑器能力
    ///（如补全、hover、code action、LSP 服务等）。
    /// `PluginVM` 会据此过滤出编辑器插件，交给 `EditorPluginManager` 安装。
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

    /// 提供项目上下文能力。
    ///
    /// 用于项目打开/关闭、上下文同步、当前文件项目快照等高层能力。
    /// 这是 editor 内核面向插件的高层入口，插件作者不需要直接理解内核内部 registry 或 bridge。
    @MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)?

    /// 提供语义可用性能力。
    ///
    /// 用于 preflight、当前文件语义环境检查，以及语言能力不可用时的错误归类。
    @MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)?

    /// 提供语言服务项目集成能力列表。
    ///
    /// 用于按语言生成 workspace folders、initialization options 等项目型语言服务集成参数。
    @MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability]

    // MARK: - Lifecycle Hooks

    /// 插件注册完成后的回调
    nonisolated func onRegister()

    /// 插件被启用时的回调
    nonisolated func onEnable()

    /// 插件被禁用时的回调
    nonisolated func onDisable()

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

    static var displayName: String { id }

    static var description: String { "" }

    static var iconName: String { "puzzlepiece" }

    static var isConfigurable: Bool { false }

    static var enable: Bool { true }
}
