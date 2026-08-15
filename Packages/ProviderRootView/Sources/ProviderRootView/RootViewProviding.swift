import SwiftUI

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
///   通常来自 `RailViewProviding`）。
///
/// 协议只声明能力，不关心具体实现。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any RootViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol RootViewProviding: AnyObject {
    /// 注入工具栏视图（传 `nil` 表示无工具栏）。
    ///
    /// 宿主通常把 `ToolbarProviding.makeToolbarView()` 的结果注入进来。
    func setToolbarView(_ view: AnyView?)

    /// 注入 ActivityBar 视图（传 `nil` 表示无 ActivityBar）。
    ///
    /// 宿主通常把 `ActivityBarProviding.makeActivityBarView()` 的结果注入进来，
    /// 显示在内容区左侧。
    func setActivityBarView(_ view: AnyView?)

    /// 注入 Rail 视图（传 `nil` 表示无 Rail）。
    ///
    /// 宿主通常把 `RailViewProviding.makeRailView()` 的结果注入进来，
    /// 显示在 ActivityBar 右侧。
    func setRailView(_ view: AnyView?)

    /// 返回根布局视图（工具栏 + 内容区，内容区左侧可带 ActivityBar 与 Rail）。
    func makeRootView() -> AnyView
}
