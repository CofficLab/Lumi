import Combine
import SwiftUI

/// 底部状态栏视图提供能力协议
///
/// 定义「内核 → 窗口底部状态栏视图」这一段的最小契约：宿主在启动时
/// 通过内核解析 `StatusBarProviding`，拿到状态栏视图后放置到窗口底部。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `addStatusBarItems(_:)`（追加）注入 `StatusBarItem`；
/// - 实现负责把注入的 items 按 `placement` 渲染成状态栏视图
///   （`makeStatusBarView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any StatusBarProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol StatusBarProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 当前已注入的全部状态栏项。
    var statusBarItems: [StatusBarItem] { get }

    /// 替换当前全部状态栏项（实现应保存 items 并在 `makeStatusBarView()` 中渲染）。
    func registerStatusBarItems(_ items: [StatusBarItem])

    /// 返回状态栏视图（基于已注入的 items 渲染）。
    func makeStatusBarView() -> AnyView
}

public extension StatusBarProviding {
    var visibleStatusBarItems: [StatusBarItem] { statusBarItems }

    /// 追加状态栏项（保留已有项）：供多个插件各自贡献时使用，互不覆盖。
    ///
    /// 默认实现合入已有项并按 `order` 排序（同 id 去重，保留先注册者）。
    func addStatusBarItems(_ items: [StatusBarItem]) {
        var merged = statusBarItems
        for item in items where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerStatusBarItems(
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

    /// 按 id 撤回插件贡献的状态栏项。
    func removeStatusBarItems(ids: Set<String>) {
        registerStatusBarItems(statusBarItems.filter { !ids.contains($0.id) })
    }
}
