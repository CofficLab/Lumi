import Combine
import SwiftUI

// MARK: - Panel Bottom Provider

/// `PanelBottomProviding` 的默认实现。
///
/// 由宿主插件（PluginRootView 的 `PanelBottomSuperPlugin`）创建并注册进内核：
/// - 入口按 `order` 升序（同权重按 id）排序，同 id 覆盖更新；
/// - `removeItems(ownerPluginID:)` 只撤回指定插件贡献的入口；
/// - 激活入口失效时先回退到持久化的历史选择，再回退到首个入口；
/// - 变更通过类型化观察者通知（状态更新完成后触发），
///   同时以 `@Published` 支持 SwiftUI 直接观察。
@MainActor
public final class PanelBottomProvider: PanelBottomProviding, ObservableObject {
    @Published public private(set) var items: [PanelBottomItem] = []
    @Published public private(set) var activeItemID: String?

    private var observers: [UUID: (PanelBottomEvent) -> Void] = [:]
    private let loadActiveItemID: @MainActor () -> String?
    private let saveActiveItemID: @MainActor (String?) -> Void
    /// 启动时持久化的历史激活入口（惰性读取一次）。
    private lazy var restoredActiveItemID: String? = loadActiveItemID()

    public init(
        loadActiveItemID: @escaping @MainActor () -> String? = { nil },
        saveActiveItemID: @escaping @MainActor (String?) -> Void = { _ in }
    ) {
        self.loadActiveItemID = loadActiveItemID
        self.saveActiveItemID = saveActiveItemID
    }

    // MARK: - 公开方法

    @discardableResult
    public func addPanelBottomObserver(
        _ callback: @escaping (PanelBottomEvent) -> Void
    ) -> any PanelBottomObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func addItems(_ newItems: [PanelBottomItem]) {
        guard !newItems.isEmpty else { return }
        var merged = items
        for item in newItems {
            if let index = merged.firstIndex(where: { $0.id == item.id }) {
                merged[index] = item
            } else {
                merged.append(item)
            }
        }
        merged.sort { lhs, rhs in
            lhs.order == rhs.order ? lhs.id < rhs.id : lhs.order < rhs.order
        }
        let previousActive = activeItemID
        items = merged
        normalizeActiveItem()
        emit(.itemsChanged)
        if activeItemID != previousActive {
            emit(.activeItemChanged(activeItemID))
        }
    }

    public func removeItems(ownerPluginID: String) {
        let remaining = items.filter { $0.ownerPluginID != ownerPluginID }
        guard remaining.count != items.count else { return }
        let previousActive = activeItemID
        items = remaining
        normalizeActiveItem()
        emit(.itemsChanged)
        if activeItemID != previousActive {
            emit(.activeItemChanged(activeItemID))
        }
    }

    public func selectItem(id: String?) {
        guard let id,
              id != activeItemID,
              items.contains(where: { $0.id == id }) else { return }
        activeItemID = id
        saveActiveItemID(id)
        emit(.activeItemChanged(id))
    }

    // MARK: - 私有方法

    /// 激活入口失效时回退：优先持久化的历史选择，其次首个入口。
    private func normalizeActiveItem() {
        if let active = activeItemID, items.contains(where: { $0.id == active }) {
            return
        }
        if let restored = restoredActiveItemID,
           items.contains(where: { $0.id == restored }) {
            activeItemID = restored
        } else {
            activeItemID = items.first?.id
        }
    }

    private func emit(_ event: PanelBottomEvent) {
        observers.values.forEach { $0(event) }
    }

    // MARK: - Observer Handle

    private final class ObserverHandle: PanelBottomObserverHandle {
        private let cancellation: () -> Void

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation()
        }
    }
}
