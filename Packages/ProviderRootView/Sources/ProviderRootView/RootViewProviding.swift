import SwiftUI

/// 根视图提供能力协议
///
/// 定义「内核 → 应用根布局视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `RootViewProviding`，拿到根布局视图后作为窗口内容展示。
///
/// 根布局模仿 Lumi 的 AppLayoutView 结构：顶部工具栏 + 内容区。
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `setToolbarView(_:)` 注入工具栏视图（通常来自 `ToolbarProviding`）；
/// - 实现负责把注入的工具栏与内容区组合成根视图（`makeRootView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any RootViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol RootViewProviding: AnyObject {
    /// 注入工具栏视图（传 `nil` 表示无工具栏）。
    ///
    /// 宿主通常把 `ToolbarProviding.makeToolbarView()` 的结果注入进来。
    func setToolbarView(_ view: AnyView?)

    /// 返回根布局视图（顶部工具栏 + 内容区）。
    func makeRootView() -> AnyView
}
