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

    /// 插件图标名称（SF Symbols）
    static var iconName: String { get }

    /// 是否可配置
    static var isConfigurable: Bool { get }

    /// 是否启用此插件
    static var enable: Bool { get }

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String { get }

    // MARK: - View Methods

    /// 添加根视图包裹
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View

    /// 包裹右侧栏根视图
    @MainActor func wrapRightSidebarRoot(_ content: AnyView, activeIcon: String?) -> AnyView

    /// 添加工具栏前导视图
    @MainActor func addToolBarLeadingView(activeIcon: String?) -> AnyView?

    /// 添加工具栏中间视图
    @MainActor func addToolBarCenterView(activeIcon: String?) -> AnyView?

    /// 添加工具栏右侧视图
    @MainActor func addToolBarTrailingView(activeIcon: String?) -> AnyView?

    /// 提供面板图标（SF Symbol 名称）
    nonisolated func addPanelIcon() -> String?

    /// 添加面板视图
    @MainActor func addPanelView(activeIcon: String?) -> AnyView?

    /// 提供 Panel Header 视图
    @MainActor func addPanelHeaderView(activeIcon: String?) -> AnyView?

    /// 提供底部面板标签页列表
    @MainActor func addBottomPanelTabs(activeIcon: String?) -> [BottomPanelTab]

    /// 提供指定底部面板 Tab 对应的内容视图
    @MainActor func addBottomPanelContentView(tabId: String, activeIcon: String?) -> AnyView?

    /// 提供 Rail 标签页列表
    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab]

    /// 提供指定 Rail tab 对应的内容视图
    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView?

    /// 添加右侧栏 Section 视图
    @MainActor func addSidebarSections(activeIcon: String?) -> [AnyView]

    /// 提供右侧栏底部工具栏左侧项列表
    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem]

    /// 提供右侧栏底部工具栏右侧项列表
    @MainActor func addSidebarTrailingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem]

    /// 提供指定右侧栏工具栏项对应的自定义按钮视图
    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView?

    /// 添加设置视图
    @MainActor func addSettingsView() -> AnyView?

    /// 添加菜单栏弹窗视图列表
    @MainActor func addMenuBarPopupViews() -> [AnyView]

    /// 添加菜单栏弹窗视图（向后兼容）
    @available(*, deprecated, message: "Use addMenuBarPopupViews() returning [AnyView] instead")
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
