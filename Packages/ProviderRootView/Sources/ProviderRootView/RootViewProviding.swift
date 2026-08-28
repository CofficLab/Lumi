import Combine
import SwiftUI
import ProviderWorkspace

/// 根视图提供能力协议
///
/// 定义「内核 → 应用根布局视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `RootViewProviding`，拿到根布局视图后作为窗口内容展示。
///
/// 根布局模仿 Lumi 的 AppLayoutView 结构：
/// - 顶部工具栏（通过 `setToolbarView(_:)` 注入，通常来自 `ToolbarProviding`）；
/// - 内容区左侧的竖直 ActivityBar（通过 `setActivityBarView(_:)` 注入，
///   通常来自 `ActivityBarProviding`）；
/// - ActivityBar 右侧的侧边栏 Rail（通过 `setRailView(_:)` 注入，
///   通常来自 `RailViewProviding`）；
/// - 内容区顶部的 Header（通过 `setContentHeaderView(_:)` 注入，
///   例如打开文件标签栏）；
/// - 内容区（通过 `setContentView(_:)` 注入，通常来自 `ContentViewProviding`）。
///
/// 协议只声明能力，不关心具体实现。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any RootViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol RootViewProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 根视图叠层贡献（例如全局搜索、预览浮层）。后注册项显示在更上层。
    var overlays: [RootOverlayItem] { get }

    /// 追加根视图叠层；同 id 的贡献不会重复注册。
    func addOverlays(_ overlays: [RootOverlayItem])

    /// 撤回根视图叠层。
    func removeOverlays(ids: Set<String>)
    /// 注入工具栏视图（传 `nil` 表示无工具栏）。
    ///
    /// 宿主通常把 `ToolbarProviding.makeToolbarView()` 的结果注入进来。
    func setToolbarView(_ view: AnyView?)

    /// 注入 ActivityBar 视图（传 `nil` 表示无 ActivityBar）。
    ///
    /// 宿主通常把 `ActivityBarProviding.makeActivityBarView()` 的结果注入进来，
    /// 显示在内容区左侧；ActivityBar 自身负责在需要显示时绘制分隔线。
    func setActivityBarView(_ view: AnyView?)

    /// 注入 Rail 视图（传 `nil` 表示无 Rail）。
    ///
    /// 宿主通常把 `RailViewProviding.makeRailView()` 的结果注入进来，
    /// 显示在 ActivityBar 右侧。
    func setRailView(_ view: AnyView?)

    /// 注入主内容区顶部视图（传 `nil` 表示没有 Header）。
    ///
    /// Header 与主内容视图独立贡献，适合项目文件标签、面包屑等横向内容。
    func setContentHeaderView(_ view: AnyView?)

    /// 注入主内容视图（传 `nil` 表示回退到占位）。
    ///
    /// 宿主通常把 `ContentViewProviding.makeContentView()` 的结果注入进来，
    /// 显示在内容区（ActivityBar / Rail 右侧）。
    func setContentView(_ view: AnyView?)

    /// 主内容区是否完全隐藏（不渲染、不占用空间）。
    ///
    /// 与 `setContentView(nil)` 的区别：后者仍会显示占位视图；
    /// 隐藏后整个内容区从视图树中移除，trailing pane 可独占全部空间。
    var isContentViewHidden: Bool { get }

    /// 设置主内容区是否完全隐藏。
    ///
    /// 隐藏后内容区不渲染、不占用内存，trailing pane（如 Chat）独占全部空间。
    /// 适用于 ChatPanel 等不需要主内容区的容器。
    func setContentViewHidden(_ hidden: Bool)

    /// 注入根布局右侧的通用面板（传 `nil` 表示没有右侧面板）。
    ///
    /// 右侧面板不限定为聊天：聊天、检查器、预览等都可以通过这个契约
    /// 接入根布局。面板的显隐状态和尺寸元数据由 `RootTrailingPane` 持有。
    func setTrailingPane(_ pane: RootTrailingPane?)

    /// 注入工作区状态机，使根 Host 按容器策略控制 Rail/Chat 显隐与持久化宽度。
    func setWorkspaceProvider(_ provider: (any WorkspaceProviding)?)

    /// 返回根布局视图（工具栏 + 内容区，内容区左侧可带 ActivityBar 与 Rail）。
    func makeRootView() -> AnyView
}

public extension RootViewProviding {
    var overlays: [RootOverlayItem] { [] }
    var isContentViewHidden: Bool { false }
    func addOverlays(_ overlays: [RootOverlayItem]) {}
    func removeOverlays(ids: Set<String>) {}
    func setContentViewHidden(_ hidden: Bool) {}
    func setWorkspaceProvider(_ provider: (any WorkspaceProviding)?) {}
}

@MainActor
public struct RootOverlayItem: Identifiable {
    public let id: String
    public let order: Int
    public let wrap: @MainActor (AnyView) -> AnyView

    public init<Content: View>(id: String, order: Int = 0, @ViewBuilder wrap: @escaping @MainActor (AnyView) -> Content) {
        self.id = id
        self.order = order
        self.wrap = { AnyView(wrap($0)) }
    }
}

/// 根布局的右侧面板描述。
@MainActor
public final class RootTrailingPane: ObservableObject {
    public let id: String
    public let minWidth: CGFloat
    public let idealWidth: CGFloat
    public let maxWidth: CGFloat
    public let content: AnyView

    @Published public var isVisible: Bool

    public init(
        id: String,
        minWidth: CGFloat = 280,
        idealWidth: CGFloat = 320,
        maxWidth: CGFloat = .infinity,
        isVisible: Bool = true,
        content: AnyView
    ) {
        self.id = id
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.isVisible = isVisible
        self.content = content
    }
}
