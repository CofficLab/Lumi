import SwiftUI

// MARK: - Default Logo Provider

/// `LogoProviding` 的默认实现：持有 Logo 项字典与顺序，按 `order` 降序对外暴露。
///
/// 插件通过 `registerLogoItem(_:)` 追加自己的 Logo 贡献（同 id 覆盖）。
/// 消费方通过 `addLogoObserver` 感知 Logo 集合与高亮状态变化。
@MainActor
public final class DefaultLogoProviding: LogoProviding {
    public private(set) var isLogoHighlighted = false
    public private(set) var allLogoItems: [LogoItem] = []

    private var logoItems: [String: LogoItem] = [:]
    private var logoItemOrder: [String] = []
    private var observers: [UUID: (LogoProvidingEvent) -> Void] = [:]

    public init() {}

    public func setLogoHighlighted(_ highlighted: Bool) {
        guard isLogoHighlighted != highlighted else { return }
        isLogoHighlighted = highlighted
        notify(.highlightChanged(highlighted))
    }

    @discardableResult
    public func addLogoObserver(
        _ callback: @escaping (LogoProvidingEvent) -> Void
    ) -> any LogoObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    public func registerLogoItem(_ item: LogoItem) {
        if logoItems[item.id] == nil {
            logoItemOrder.append(item.id)
        }
        logoItems[item.id] = item
        updateSortedItems()
        notify(.itemsChanged)
    }

    public func unregisterLogoItem(id: String) {
        logoItems.removeValue(forKey: id)
        logoItemOrder.removeAll { $0 == id }
        updateSortedItems()
        notify(.itemsChanged)
    }

    public func clearAllContributions() {
        logoItems.removeAll()
        logoItemOrder.removeAll()
        updateSortedItems()
        notify(.itemsChanged)
    }

    private func updateSortedItems() {
        allLogoItems = logoItemOrder.compactMap { logoItems[$0] }
            .sorted { $0.order > $1.order }
    }

    private func notify(_ event: LogoProvidingEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: LogoObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
