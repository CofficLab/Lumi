import SwiftUI

/// 工具栏视图提供能力协议
///
/// 定义「内核 → 标题栏工具栏视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `ToolbarProviding`，拿到工具栏根视图后放置到窗口顶部。
///
/// 协议只声明能力（返回一个工具栏视图），不关心具体实现——
/// 内容、布局、交互均由注入的实现决定。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ToolbarProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol ToolbarProviding: AnyObject {
    /// 返回工具栏视图。
    func makeToolbarView() -> AnyView
}
