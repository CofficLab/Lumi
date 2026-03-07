import AppKit
import SwiftUI

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
    ///
    /// 在主窗口工具栏的左侧添加自定义视图。
    /// 常用于：
    /// - 导航按钮
    /// - 快捷操作
    /// - 自定义标题区域
    ///
    /// - Returns: 要添加到工具栏前导的视图，如果不需要则返回 nil
    @MainActor func addToolBarLeadingView() -> AnyView?

    /// 添加工具栏右侧视图
    ///
    /// 在主窗口工具栏的右侧添加自定义视图。
    /// 常用于：
    /// - 设置按钮
    /// - 帮助按钮
    /// - 用户头像
    ///
    /// - Returns: 要添加到工具栏右侧的视图，如果不需要则返回 nil
    @MainActor func addToolBarTrailingView() -> AnyView?

    /// 添加详情视图
    ///
    /// 在应用主内容区域添加详情视图。
    /// 通常用于显示选中项的详细信息。
    ///
    /// - Returns: 要添加的详情视图，如果不需要则返回 nil
    @MainActor func addDetailView() -> AnyView?

    /// 添加设置视图
    ///
    /// 在设置面板中添加插件的配置界面。
    /// 如果插件需要用户配置选项，应实现此方法。
    ///
    /// - Returns: 要添加的设置视图，如果不需要则返回 nil
    @MainActor func addSettingsView() -> AnyView?
    
    /// 提供导航入口（用于侧边栏导航）
    ///
    /// 在侧边栏中添加导航项，点击后可切换到对应的内容视图。
    /// 可以返回多个导航项来创建嵌套结构。
    ///
    /// - Returns: 导航入口数组，如果不需要则返回 nil
    @MainActor func addNavigationEntries() -> [NavigationEntry]?

    /// 添加状态栏弹窗视图
    ///
    /// 当用户点击菜单栏图标时显示的弹出视图。
    /// 常用于：
    /// - 快速操作面板
    /// - 状态摘要
    /// - 快捷设置
    ///
    /// - Returns: 要添加到状态栏弹窗的视图，如果不需要则返回 nil
    @MainActor func addStatusBarPopupView() -> AnyView?

    /// 添加状态栏内容视图
    ///
    /// 直接显示在菜单栏图标位置的视图。
    /// 与弹窗视图不同，内容视图始终可见。
    /// 常用于：
    /// - 实时状态指示器
    /// - 动态图标
    /// - 简短数据展示
    ///
    /// - Returns: 要显示在状态栏图标位置的视图，如果不需要则返回 nil
    /// - Note: 插件可以提供自定义的状态栏内容视图，内核会将其组合显示
    @MainActor func addStatusBarContentView() -> AnyView?

    /// 添加侧边栏视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于屏幕左侧的视图。
    /// 多个插件的侧边栏视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 对话列表
    /// - 文件树
    /// - 项目结构
    ///
    /// - Returns: 要添加的侧边栏视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的侧边栏视图，多个插件的侧边栏会从上到下垂直堆叠显示
    @MainActor func addSidebarView() -> AnyView?

    /// 添加中间栏视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于侧边栏和详情栏之间的视图。
    /// 多个插件的中间栏视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 文件预览
    /// - 代码查看器
    /// - 媒体预览
    ///
    /// - Returns: 要添加的中间栏视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的中间栏视图，位于侧边栏和详情栏之间，多个插件的中间栏会从上到下垂直堆叠显示
    @MainActor func addMiddleView() -> AnyView?

    /// 添加详情栏头部视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于详情栏顶部的视图。
    /// 多个插件的头部视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 聊天头部信息
    /// - 工具栏
    /// - 搜索框
    ///
    /// - Returns: 要添加的详情栏头部视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的详情栏头部视图，多个插件的头部视图会从上到下垂直堆叠显示
    @MainActor func addDetailHeaderView() -> AnyView?

    /// 添加详情栏中间视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于详情栏中部的视图。
    /// 多个插件的中间视图会从上到下垂直堆叠显示。
    /// 此区域通常用于显示主要内容和消息列表。
    ///
    /// - Returns: 要添加的详情栏中间视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的详情栏中间视图（消息列表），多个插件的中间视图会从上到下垂直堆叠显示
    @MainActor func addDetailMiddleView() -> AnyView?

    /// 添加详情栏底部视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于详情栏底部的视图。
    /// 多个插件的底部视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 输入区域
    /// - 发送按钮
    /// - 附件上传
    ///
    /// - Returns: 要添加的详情栏底部视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的详情栏底部视图（输入区域），多个插件的底部视图会从上到下垂直堆叠显示
    @MainActor func addDetailBottomView() -> AnyView?

    // MARK: - Lifecycle Hooks

    /// 插件注册完成后的回调
    ///
    /// 当插件被自动发现并注册到系统后调用。
    /// 此时插件已准备好，但可能尚未显示在 UI 中。
    /// 适合执行：
    /// - 初始化插件状态
    /// - 加载持久化配置
    /// - 注册通知观察者
    nonisolated func onRegister()

    /// 插件被启用时的回调
    ///
    /// 当插件从禁用状态变为启用状态时调用。
    /// 此时插件将开始参与 UI 渲染和交互。
    /// 适合执行：
    /// - 启动后台任务
    /// - 连接外部服务
    /// - 更新 UI 状态
    nonisolated func onEnable()

    /// 插件被禁用时的回调
    ///
    /// 当插件从启用状态变为禁用状态时调用。
    /// 此时插件将停止参与 UI 渲染和交互。
    /// 适合执行：
    /// - 停止后台任务
    /// - 断开外部连接
    /// - 保存状态
    nonisolated func onDisable()

    /// 插件注册顺序（数字越小越先加载）
    ///
    /// 决定插件在列表中的排序位置。
    /// 数字越小，优先级越高，越早被加载和处理。
    /// 建议：
    /// - 0-99: 系统核心插件
    /// - 100-499: 主要功能插件
    /// - 500-999: 辅助功能插件
    static var order: Int { get }
}

// MARK: - Default Implementation

extension SuperPlugin {
    /// 自动派生插件 ID（类名去掉 "Plugin" 后缀）
    ///
    /// 例如：`MyCustomPlugin` -> `"MyCustom"`
    static var id: String {
        String(describing: self)
            .replacingOccurrences(of: "Plugin", with: "")
    }
    
    /// 默认实例标签
    ///
    /// 返回插件 ID 作为实例标签。
    nonisolated var instanceLabel: String { Self.id }
    
    /// 默认显示名称
    ///
    /// 使用插件 ID 作为显示名称。
    static var displayName: String { id }
    
    /// 默认描述
    ///
    /// 默认返回空字符串。
    static var description: String { "" }
    
    /// 默认图标
    ///
    /// 使用 SF Symbols 的 `puzzlepiece` 作为默认图标。
    static var iconName: String { "puzzlepiece" }
    
    /// 默认可配置
    ///
    /// 默认情况下插件不可配置，始终启用。
    static var isConfigurable: Bool { false }
    
    /// 默认启用插件
    ///
    /// 默认情况下插件是启用的。
    static var enable: Bool { true }

    /// 默认实现：不提供根视图包裹
    ///
    /// 返回 nil 表示不包裹根视图。
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View { nil }

    /// 提供根视图（接收 AnyView 参数的便捷方法）
    ///
    /// 内部调用 `addRootView`，将 AnyView 转换为 ViewBuilder。
    @MainActor func provideRootView(_ content: AnyView) -> AnyView? {
        self.addRootView { content }
    }

    /// 包裹根视图（安全版本）
    ///
    /// 如果插件提供了根视图包装，则返回包装后的视图；
    /// 否则返回原始视图。
    ///
    /// - Parameter content: 要包裹的视图
    /// - Returns: 包裹后的视图
    @MainActor func wrapRoot(_ content: AnyView) -> AnyView {
        if let wrapped = self.provideRootView(content) {
            return wrapped
        }
        return content
    }

    /// 默认实现：不提供工具栏前导视图
    @MainActor func addToolBarLeadingView() -> AnyView? { nil }
    
    /// 默认实现：不提供工具栏右侧视图
    @MainActor func addToolBarTrailingView() -> AnyView? { nil }
    
    /// 默认实现：不提供详情视图
    @MainActor func addDetailView() -> AnyView? { nil }

    /// 默认实现：不提供设置视图
    @MainActor func addSettingsView() -> AnyView? { nil }

    /// 默认实现：不提供导航入口
    @MainActor func addNavigationEntries() -> [NavigationEntry]? { nil }

    /// 默认实现：不提供弹窗视图
    @MainActor func addStatusBarPopupView() -> AnyView? { nil }

    /// 默认实现：不提供状态栏内容视图
    @MainActor func addStatusBarContentView() -> AnyView? { nil }

    /// 默认实现：不提供侧边栏视图
    @MainActor func addSidebarView() -> AnyView? { nil }

    /// 默认实现：不提供中间栏视图
    @MainActor func addMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏头部视图
    @MainActor func addDetailHeaderView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏中间视图
    @MainActor func addDetailMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏底部视图
    @MainActor func addDetailBottomView() -> AnyView? { nil }

    // MARK: - Lifecycle Hooks Default Implementation
    
    /// 默认实现：注册完成后不执行任何操作
    nonisolated func onRegister() {}
    
    /// 默认实现：启用时不执行任何操作
    nonisolated func onEnable() {}
    
    /// 默认实现：禁用时不执行任何操作
    nonisolated func onDisable() {}
    
    // MARK: - Configuration Defaults

    /// 默认注册顺序 (999)
    ///
    /// 较高的默认值确保核心插件优先加载。
    static var order: Int { 999 }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}