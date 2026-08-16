import SwiftUI

/// Rail（侧边栏）视图提供能力协议
///
/// 定义「内核 → 侧边栏 Rail 视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `RailViewProviding`，拿到 Rail 视图后放置到窗口左侧
/// （通常位于 ActivityBar 右侧、内容区左侧）。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerTabs(_:)` 注入 `RailTabItem`；
/// - 实现负责把注入的 tabs 渲染成「标签栏 + 内容区」的 Rail 视图
///   （`makeRailView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any RailViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol RailViewProviding: AnyObject {
    /// 当前已注入的全部 Rail tab 项。
    var tabs: [RailTabItem] { get }

    /// 注入 Rail tab 项（替换当前全部项）。
    func registerTabs(_ tabs: [RailTabItem])

    /// 按 id 撤回插件贡献的标签。
    func removeTabs(ids: Set<String>)

    /// 返回 Rail 视图（基于已注入的 tabs 渲染）。
    func makeRailView() -> AnyView
}

public extension RailViewProviding {
    func removeTabs(ids: Set<String>) {
        registerTabs(tabs.filter { !ids.contains($0.id) })
    }
}
