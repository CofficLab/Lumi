import SwiftUI

/// ActivityBar 视图提供能力协议
///
/// 定义「内核 → ActivityBar 侧边入口栏」这一段的最小契约：宿主在启动时
/// 通过内核解析 `ActivityBarProviding`，拿到 ActivityBar 视图后放置到窗口左侧。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerItems(_:)` 注入 `ActivityBarItem`（图标入口）；
/// - 实现负责把注入的 items 渲染成 ActivityBar 视图（`makeActivityBarView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ActivityBarProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol ActivityBarProviding: AnyObject {
    /// 当前已注入的全部 ActivityBar 项。
    var items: [ActivityBarItem] { get }

    /// 注入 ActivityBar 项（替换当前全部项）。
    func registerItems(_ items: [ActivityBarItem])

    /// 返回 ActivityBar 视图（基于已注入的 items 渲染）。
    func makeActivityBarView() -> AnyView
}
