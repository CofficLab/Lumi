import LumiCoreKit

/// 布局持久化协调器
///
/// 仅负责从磁盘读取已保存的布局状态并写入 `LumiCore.layoutState`。
/// 事件监听和持久化写入由 `LayoutPersistenceAnchor` 视图处理。
@MainActor
final class LayoutPersistenceCoordinator {
    static let shared = LayoutPersistenceCoordinator()

    private init() {}

    /// 从磁盘恢复布局状态到内核
    func restore() {
        guard let state = LumiCore.layoutState else {
            if LayoutPlugin.verbose {
                LayoutPlugin.logger.warning("\(LayoutPlugin.t)LumiCore.layoutState 未初始化，跳过恢复")
            }
            return
        }

        let store = LayoutPluginLocalStore.shared
        var restored: [String] = []

        if let id = store.loadActiveViewContainerID() {
            state.activeViewContainerID = id
            restored.append("activeViewContainerID=\(id)")
        }
        if let tabId = store.loadSelectedAgentSidebarTabId() {
            state.activeRailTabID = tabId
            restored.append("activeRailTabID=\(tabId)")
        }
        if let bottomTabId = store.string(forKey: LayoutStorageKey.activeBottomTabID) {
            state.activeBottomTabID = bottomTabId
            restored.append("activeBottomTabID=\(bottomTabId)")
        }
        if let visible = store.loadBottomPanelVisible() {
            state.bottomPanelVisible = visible
            restored.append("bottomPanelVisible=\(visible)")
        }
        if let visible = store.loadContentPanelVisible() {
            state.chatSectionVisible = visible
            restored.append("chatSectionVisible=\(visible)")
        }

        if LayoutPlugin.verbose {
            if restored.isEmpty {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)磁盘无已保存布局，使用默认值")
            } else {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)已从磁盘恢复: \(restored.joined(separator: ", "))")
            }
        }
    }
}
