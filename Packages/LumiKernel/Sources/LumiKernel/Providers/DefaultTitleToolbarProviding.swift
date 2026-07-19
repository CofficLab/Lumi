import Foundation
import SwiftUI

// MARK: - Default Title Toolbar Provider

/// 默认标题栏工具栏服务实现
///
/// 负责管理所有插件的标题栏工具栏项的注册、排序和查询。
@MainActor
public final class DefaultTitleToolbarProviding: TitleToolbarProviding {
    public private(set) var allTitleToolbarItems: [TitleToolbarItem] = []

    private var titleToolbarItems: [String: TitleToolbarItem] = [:]
    private var titleToolbarItemOrder: [String] = []

    public init() {}

    public func titleToolbarItems(placement: TitleToolbarPlacement) -> [TitleToolbarItem] {
        allTitleToolbarItems.filter { $0.placement == placement }
    }

    public func registerTitleToolbarItem(_ item: TitleToolbarItem) {
        if titleToolbarItems[item.id] == nil {
            titleToolbarItemOrder.append(item.id)
        }
        titleToolbarItems[item.id] = item
        updateSortedItems()
    }

    public func unregisterTitleToolbarItem(id: String) {
        titleToolbarItems.removeValue(forKey: id)
        titleToolbarItemOrder.removeAll { $0 == id }
        updateSortedItems()
    }

    private func updateSortedItems() {
        allTitleToolbarItems = titleToolbarItemOrder.compactMap { titleToolbarItems[$0] }
            .sorted { $0.order < $1.order }
    }
}
