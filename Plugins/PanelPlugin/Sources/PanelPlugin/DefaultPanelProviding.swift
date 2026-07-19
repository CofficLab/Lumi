import Foundation
import LumiKernel
import SwiftUI

// MARK: - Default Panel Provider

/// 默认面板服务实现
///
/// 负责管理所有插件的面板项（顶部标题栏、底部标签、侧边栏标签）的注册、排序和查询。
@MainActor
public final class DefaultPanelProviding: PanelProviding {
    public private(set) var allPanelHeaderItems: [PanelHeaderItem] = []
    public private(set) var allPanelBottomTabItems: [PanelBottomTabItem] = []
    public private(set) var allPanelRailTabItems: [PanelRailTabItem] = []

    private var headerItems: [String: PanelHeaderItem] = [:]
    private var headerItemOrder: [String] = []
    private var bottomTabItems: [String: PanelBottomTabItem] = [:]
    private var bottomTabOrder: [String] = []
    private var railTabItems: [String: PanelRailTabItem] = [:]
    private var railTabOrder: [String] = []

    public init() {}

    public func registerPanelHeaderItem(_ item: PanelHeaderItem) {
        if headerItems[item.id] == nil {
            headerItemOrder.append(item.id)
        }
        headerItems[item.id] = item
        updateSortedHeaders()
    }

    public func unregisterPanelHeaderItem(id: String) {
        headerItems.removeValue(forKey: id)
        headerItemOrder.removeAll { $0 == id }
        updateSortedHeaders()
    }

    public func registerPanelBottomTabItem(_ item: PanelBottomTabItem) {
        if bottomTabItems[item.id] == nil {
            bottomTabOrder.append(item.id)
        }
        bottomTabItems[item.id] = item
        updateSortedBottomTabs()
    }

    public func unregisterPanelBottomTabItem(id: String) {
        bottomTabItems.removeValue(forKey: id)
        bottomTabOrder.removeAll { $0 == id }
        updateSortedBottomTabs()
    }

    public func registerPanelRailTabItem(_ item: PanelRailTabItem) {
        if railTabItems[item.id] == nil {
            railTabOrder.append(item.id)
        }
        railTabItems[item.id] = item
        updateSortedRailTabs()
    }

    public func unregisterPanelRailTabItem(id: String) {
        railTabItems.removeValue(forKey: id)
        railTabOrder.removeAll { $0 == id }
        updateSortedRailTabs()
    }

    private func updateSortedHeaders() {
        allPanelHeaderItems = headerItemOrder.compactMap { headerItems[$0] }
    }

    private func updateSortedBottomTabs() {
        allPanelBottomTabItems = bottomTabOrder.compactMap { bottomTabItems[$0] }
            .sorted { $0.order < $1.order }
    }

    private func updateSortedRailTabs() {
        allPanelRailTabItems = railTabOrder.compactMap { railTabItems[$0] }
            .sorted { $0.order < $1.order }
    }
}
