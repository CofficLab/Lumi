import LumiCoreKit
import SwiftUI

/// 布局持久化锚点视图
///
/// 挂载到 RootOverlay 上，负责：
/// 1. App 启动时从磁盘恢复布局状态
/// 2. 监听内核发出的布局变更事件并持久化
struct LayoutPersistenceAnchor: View {
    let content: AnyView
    @State private var hasRestored = false

    var body: some View {
        content
            .onAppear {
                guard !hasRestored else { return }
                hasRestored = true

                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)布局持久化锚点已挂载")
                }
                LayoutPersistenceCoordinator.shared.restore()
            }
            // 监听内核发出的布局变更事件
            .onReceive(NotificationCenter.default.publisher(for: .activeViewContainerIDDidChange)) { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeViewContainerID → \(containerID)")
                }
                LayoutPluginLocalStore.shared.saveActiveViewContainerID(containerID)
            }
            .onReceive(NotificationCenter.default.publisher(for: .activeRailTabIDDidChange)) { notification in
                guard let railTabID = notification.userInfo?["railTabID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeRailTabID → \(railTabID)")
                }
                LayoutPluginLocalStore.shared.saveSelectedAgentSidebarTabId(railTabID)
            }
            .onReceive(NotificationCenter.default.publisher(for: .activeBottomTabIDDidChange)) { notification in
                guard let bottomTabID = notification.userInfo?["bottomTabID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeBottomTabID → \(bottomTabID)")
                }
                LayoutPluginLocalStore.shared.set(bottomTabID, forKey: LayoutStorageKey.activeBottomTabID)
            }
            .onReceive(NotificationCenter.default.publisher(for: .bottomPanelVisibleDidChange)) { notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: bottomPanelVisible → \(visible)")
                }
                LayoutPluginLocalStore.shared.saveBottomPanelVisible(visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .chatSectionVisibleDidChange)) { notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: chatSectionVisible → \(visible)")
                }
                LayoutPluginLocalStore.shared.set(visible, forKey: LayoutStorageKey.chatSectionVisible)
            }
    }
}
