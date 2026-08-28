import Combine
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
public protocol RailViewProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 当前已注入的全部 Rail tab 项。
    var tabs: [RailTabItem] { get }

    /// 当前允许展示的 Rail 分类。空集合表示不展示任何 Rail tab。
    var visibleCategories: Set<RailViewCategory> { get }

    /// 当前允许展示的 Rail tab id。为 nil 时不按 id 限制。
    var visibleTabID: String? { get }

    /// 当前激活的标签。
    var activeTabID: String? { get }

    /// 注入 Rail tab 项（替换当前全部项）。
    func registerTabs(_ tabs: [RailTabItem])

    /// 追加插件贡献的标签，不覆盖其他插件的贡献。
    func addTabs(_ tabs: [RailTabItem])

    /// 按 id 撤回插件贡献的标签。
    func removeTabs(ids: Set<String>)

    /// 设置当前允许展示的 Rail 分类。
    func setVisibleCategories(_ categories: Set<RailViewCategory>)

    /// 设置当前允许展示的 Rail tab id。传入 nil 表示取消 id 限制。
    func setVisibleTabID(_ id: String?)

    /// 切换标签；未知 id 将被忽略。
    func activateTab(id: String?)

    /// 返回 Rail 视图（基于已注入的 tabs 渲染）。
    func makeRailView() -> AnyView
}

public extension RailViewProviding {
    var visibleCategories: Set<RailViewCategory> { Set(RailViewCategory.allCases) }

    var visibleTabID: String? { nil }

    var activeTabID: String? { nil }

    func addTabs(_ newTabs: [RailTabItem]) {
        var merged = tabs
        for tab in newTabs where !merged.contains(where: { $0.id == tab.id }) {
            merged.append(tab)
        }
        registerTabs(merged)
    }

    func removeTabs(ids: Set<String>) {
        registerTabs(tabs.filter { !ids.contains($0.id) })
    }

    func setVisibleCategories(_ categories: Set<RailViewCategory>) {}

    func setVisibleTabID(_ id: String?) {}

    func activateTab(id: String?) {}
}
