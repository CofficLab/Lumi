import SwiftUI

// MARK: - Events & Observer

/// PanelBottom 的类型化变更事件。
@MainActor
public enum PanelBottomEvent {
    /// 入口集合发生变化（增删 / 排序）。
    case itemsChanged
    /// 激活入口发生变化。
    case activeItemChanged(String?)
}

@MainActor
public protocol PanelBottomObserverHandle: AnyObject {
    func cancel()
}

// MARK: - Providing

/// 底部面板入口贡献能力协议。
///
/// 定义「插件 → 底部面板 tab 入口」这一段的最小契约：
/// - 插件通过 `addItems(_:)` 注册自己的 tab 入口，`removeItems(ownerPluginID:)` 撤回；
/// - 宿主（PluginRootView 的 PanelBottomSuperPlugin）负责把入口渲染为
///   content footer 中的 tab 容器，并按 `hasVisibleItems` 安装/卸载容器；
/// - 观察者通过 `addPanelBottomObserver(_:)` 感知变化（在状态更新完成后触发）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any PanelBottomProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol PanelBottomProviding: AnyObject {
    /// 当前已注入的全部入口（按 `order` 升序）。
    var items: [PanelBottomItem] { get }

    /// 当前激活入口；无入口时为 nil。
    var activeItemID: String? { get }

    /// 是否至少有一个入口（宿主据此决定是否安装 footer 容器）。
    var hasVisibleItems: Bool { get }

    /// 注册变更观察者（回调在状态更新完成后触发）。
    @discardableResult
    func addPanelBottomObserver(
        _ callback: @escaping (PanelBottomEvent) -> Void
    ) -> any PanelBottomObserverHandle

    /// 追加入口（同 id 覆盖更新），并按 `order` 重排。
    func addItems(_ items: [PanelBottomItem])

    /// 按归属插件批量撤回入口。
    func removeItems(ownerPluginID: String)

    /// 切换激活入口。未知 id 忽略。
    func selectItem(id: String?)
}

public extension PanelBottomProviding {
    var hasVisibleItems: Bool { !items.isEmpty }

    @discardableResult
    func addPanelBottomObserver(
        _ callback: @escaping (PanelBottomEvent) -> Void
    ) -> any PanelBottomObserverHandle {
        NoopPanelBottomObserverHandle()
    }

    func selectItem(id: String?) {}
}

@MainActor
private final class NoopPanelBottomObserverHandle: PanelBottomObserverHandle {
    func cancel() {}
}
