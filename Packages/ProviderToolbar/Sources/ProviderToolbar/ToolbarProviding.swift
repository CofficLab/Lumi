import Combine
import SwiftUI

/// 工具栏视图提供能力协议
///
/// 定义「内核 → 标题栏工具栏视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `ToolbarProviding`，拿到工具栏视图后放置到窗口顶部。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerToolbarItems(_:)`（替换）或 `addToolbarItems(_:)`（追加）
///   注入 `ToolbarItem`；
/// - 实现负责把注入的 items 按 `placement` 渲染成工具栏视图（`makeToolbarView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any ToolbarProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol ToolbarProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 当前已注入的全部工具栏项。
    var toolbarItems: [ToolbarItem] { get }

    /// 注入工具栏项（替换当前全部项）。
    ///
    /// 实现应保存 items，并在 `makeToolbarView()` 中按 `placement` 渲染。
    func registerToolbarItems(_ items: [ToolbarItem])

    /// 追加工具栏项（保留已有项）。
    ///
    /// 供多个插件各自贡献工具栏项时使用，互不覆盖。
    func addToolbarItems(_ items: [ToolbarItem])

    /// 按 id 撤回插件贡献的工具栏项。
    func removeToolbarItems(ids: Set<String>)

    /// 返回工具栏视图（基于已注入的 items 渲染）。
    func makeToolbarView() -> AnyView
}

public extension ToolbarProviding {
    /// 追加语义的默认实现：合入已有项并按 `order` 排序（同 id 去重，保留先注册者）。
    func addToolbarItems(_ newItems: [ToolbarItem]) {
        var merged = toolbarItems
        for item in newItems where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerToolbarItems(
            merged.enumerated()
                .sorted { lhs, rhs in
                    if lhs.element.order != rhs.element.order {
                        return lhs.element.order < rhs.element.order
                    }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)
        )
    }

    func removeToolbarItems(ids: Set<String>) {
        registerToolbarItems(toolbarItems.filter { !ids.contains($0.id) })
    }
}
