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

    /// 只有至少两个入口时才显示 ActivityBar。
    var shouldDisplayActivityBar: Bool { get }

    /// 当前激活入口；无入口时为 nil。
    var activeItemID: String? { get }

    /// 注入 ActivityBar 项（替换当前全部项）。
    func registerItems(_ items: [ActivityBarItem])

    /// 追加 ActivityBar 项（保留已有项）。
    ///
    /// 供多个插件各自贡献入口时使用，互不覆盖。
    func addItems(_ items: [ActivityBarItem])

    /// 按 id 撤回插件贡献的入口项。
    func removeItems(ids: Set<String>)

    /// 激活指定入口。未知 id 忽略；传 nil 表示清除激活。
    func activateItem(id: String?)

    /// 返回 ActivityBar 视图（基于已注入的 items 渲染）。
    func makeActivityBarView() -> AnyView
}

public extension ActivityBarProviding {
    var shouldDisplayActivityBar: Bool { items.count > 1 }

    var activeItemID: String? { nil }

    /// 追加语义的默认实现：合入已有项并按 `order` 排序（同 id 去重，保留先注册者）。
    func addItems(_ newItems: [ActivityBarItem]) {
        var merged = items
        for item in newItems where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerItems(merged)
    }

    func removeItems(ids: Set<String>) {
        registerItems(items.filter { !ids.contains($0.id) })
    }

    func activateItem(id: String?) {}
}
