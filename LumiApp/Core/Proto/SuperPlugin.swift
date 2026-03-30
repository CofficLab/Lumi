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
/// 3. **禁用阶段**: 插件从 UI 移除，调用 `onDisable()`
///
/// ## 插件类型
///
/// Lumi 支持以下类型的插件扩展点：
/// - 侧边栏导航项
/// - 工具栏视图（前后导区域）
/// - 详情视图
/// - 设置视图
/// - 状态栏视图（弹窗和内容）
/// - Agent 模式专用视图（侧边栏、中间栏、详情栏头部/中间/底部）
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
///
///     static var isConfigurable: Bool { true }
///
///     @MainActor
///     func addNavigationEntries() -> [NavigationEntry]? {
///         [
///             NavigationEntry(
///                 id: "my-plugin",
///                 title: "我的插件",
///                 icon: "star.fill",
///                 contentProvider: { AnyView(MyPluginView()) }
///             )
///         ]
///     }
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
    @MainActor func addToolBarLeadingView() -> AnyView?

    /// 添加工具栏右侧视图
    @MainActor func addToolBarTrailingView() -> AnyView?

    /// 添加详情视图
    @MainActor func addDetailView() -> AnyView?

    /// 添加设置视图
    @MainActor func addSettingsView() -> AnyView?

    /// 提供导航入口（用于侧边栏导航）
    @MainActor func addNavigationEntries() -> [NavigationEntry]?

    /// 添加状态栏弹窗视图
    @MainActor func addStatusBarPopupView() -> AnyView?

    /// 添加状态栏内容视图
    @MainActor func addStatusBarContentView() -> AnyView?

    /// 添加侧边栏视图（用于 Agent 模式）
    @MainActor func addSidebarView() -> AnyView?

    /// 添加右侧栏头部左侧视图（用于 Agent 模式，与 trailing 组合成单一 header）
    @MainActor func addRightHeaderLeadingView() -> AnyView?

    /// 添加右侧栏头部右侧小功能视图列表（用于 Agent 模式，多个插件可各自注入）
    @MainActor func addRightHeaderTrailingItems() -> [AnyView]

    /// 添加右侧栏中间视图（用于 Agent 模式）
    @MainActor func addRightMiddleView() -> AnyView?

    /// 添加右侧栏底部视图（用于 Agent 模式）
    @MainActor func addRightBottomView() -> AnyView?

    /// 添加状态栏左侧视图（用于 Agent 模式底部状态栏）
    @MainActor func addStatusBarLeadingView() -> AnyView?

    /// 添加状态栏右侧视图（用于 Agent 模式底部状态栏）
    @MainActor func addStatusBarTrailingView() -> AnyView?

    // MARK: - Agent Tools Hooks

    /// 提供 Agent 工具列表。
    @MainActor func agentTools() -> [AgentTool]

    /// 提供 Agent 工具工厂列表（带依赖注入）。
    @MainActor func agentToolFactories() -> [AnyAgentToolFactory]

    // MARK: - Send Pipeline

    /// 提供「用户消息入队 → 发送模型」管线中间件（按插件 `order` 与中间件 `order` 排序）。
    @MainActor func sendMiddlewares() -> [AnySendMiddleware]

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
