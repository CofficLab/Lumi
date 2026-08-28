import SwiftUI

// MARK: - Default Logo Provider

/// `LogoProviding` 的默认实现：持有 Logo 项字典与顺序，按 `order` 降序对外暴露。
///
/// 插件通过 `registerLogoItem(_:)` 追加自己的 Logo 贡献（同 id 覆盖）。
/// 消费方订阅 `objectWillChange` 即可感知 Logo 集合变化。
@MainActor
public final class DefaultLogoProviding: LogoProviding {
    @Published public private(set) var isLogoHighlighted = false
    public private(set) var allLogoItems: [LogoItem] = []

    private var logoItems: [String: LogoItem] = [:]
    private var logoItemOrder: [String] = []

    public init() {}

    public func setLogoHighlighted(_ highlighted: Bool) {
        guard isLogoHighlighted != highlighted else { return }
        isLogoHighlighted = highlighted
    }

    public func registerLogoItem(_ item: LogoItem) {
        if logoItems[item.id] == nil {
            logoItemOrder.append(item.id)
        }
        logoItems[item.id] = item
        updateSortedItems()
    }

    public func unregisterLogoItem(id: String) {
        logoItems.removeValue(forKey: id)
        logoItemOrder.removeAll { $0 == id }
        updateSortedItems()
    }

    public func clearAllContributions() {
        logoItems.removeAll()
        logoItemOrder.removeAll()
        updateSortedItems()
    }

    private func updateSortedItems() {
        allLogoItems = logoItemOrder.compactMap { logoItems[$0] }
            .sorted { $0.order > $1.order }
    }
}
