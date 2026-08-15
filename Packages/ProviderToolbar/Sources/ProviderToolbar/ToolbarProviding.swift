import SwiftUI

/// 工具栏视图提供能力协议
///
/// 定义「内核 → 标题栏工具栏视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `ToolbarProviding`，拿到工具栏视图后放置到窗口顶部。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerToolbarItems(_:)` 注入 `ToolbarItem`；
/// - 实现负责把注入的 items 按 `placement` 渲染成工具栏视图（`makeToolbarView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ToolbarProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol ToolbarProviding: AnyObject {
    /// 当前已注入的全部工具栏项。
    var toolbarItems: [ToolbarItem] { get }

    /// 注入工具栏项（替换当前全部项）。
    ///
    /// 实现应保存 items，并在 `makeToolbarView()` 中按 `placement` 渲染。
    func registerToolbarItems(_ items: [ToolbarItem])

    /// 返回工具栏视图（基于已注入的 items 渲染）。
    func makeToolbarView() -> AnyView
}
