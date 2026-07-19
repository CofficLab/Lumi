import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Status Bar Provider

/// 默认状态栏服务实现
///
/// 负责管理所有插件的状态栏项的注册和查询。
@MainActor
public final class DefaultStatusBarProviding: StatusBarProviding {
    public private(set) var allStatusBarItems: [StatusBarItem] = []

    private var statusBarItems: [String: StatusBarItem] = [:]
    private var statusBarItemOrder: [String] = []

    public init() {}

    public func statusBarItems(placement: StatusBarPlacement) -> [StatusBarItem] {
        allStatusBarItems.filter { $0.placement == placement }
    }

    public func registerStatusBarItem(_ item: StatusBarItem) {
        if statusBarItems[item.id] == nil {
            statusBarItemOrder.append(item.id)
        }
        statusBarItems[item.id] = item
        updateSortedItems()
    }

    public func unregisterStatusBarItem(id: String) {
        statusBarItems.removeValue(forKey: id)
        statusBarItemOrder.removeAll { $0 == id }
        updateSortedItems()
    }

    private func updateSortedItems() {
        allStatusBarItems = statusBarItemOrder.compactMap { statusBarItems[$0] }
    }
}
