import LumiCoreKit
import SwiftUI
import Combine

/// 布局持久化锚点视图
///
/// 挂载到 RootOverlay 上，负责：
/// 1. 实例化时开始监听内核发出的布局变更事件
/// 2. 视图 onAppear 时从磁盘恢复布局状态
struct LayoutRootView: View {
    let content: AnyView
    @StateObject private var listener: LayoutEventListener
    @State private var hasRestored = false

    init(content: AnyView) {
        self.content = content
        self._listener = StateObject(wrappedValue: LayoutEventListener())
    }

    var body: some View {
        content
            .onAppear {
                guard !hasRestored else { return }
                hasRestored = true
                LayoutPersistenceCoordinator.shared.restore()
            }
    }
}

/// 布局事件监听器
///
/// 使用 Combine 订阅 `NotificationCenter` 事件，
/// 实例化即开始监听，不依赖视图挂载。
@MainActor
final class LayoutEventListener: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        if LayoutPlugin.verbose {
            LayoutPlugin.logger.info("\(LayoutPlugin.t)开始监听布局变更事件")
        }

        NotificationCenter.default.publisher(for: .activeViewContainerIDDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeViewContainerID → \(containerID)")
                }
                LayoutPluginLocalStore.shared.saveActiveViewContainerID(containerID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .activeRailTabIDDidChange)
            .sink { notification in
                guard let railTabID = notification.userInfo?["railTabID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeRailTabID → \(railTabID)")
                }
                LayoutPluginLocalStore.shared.saveSelectedAgentSidebarTabId(railTabID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .activeBottomTabIDDidChange)
            .sink { notification in
                guard let bottomTabID = notification.userInfo?["bottomTabID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeBottomTabID → \(bottomTabID)")
                }
                LayoutPluginLocalStore.shared.set(bottomTabID, forKey: LayoutStorageKey.activeBottomTabID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .bottomPanelVisibleDidChange)
            .sink { notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: bottomPanelVisible → \(visible)")
                }
                LayoutPluginLocalStore.shared.saveBottomPanelVisible(visible)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .chatSectionVisibleDidChange)
            .sink { notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: chatSectionVisible → \(visible)")
                }
                LayoutPluginLocalStore.shared.set(visible, forKey: LayoutStorageKey.chatSectionVisible)
            }
            .store(in: &cancellables)
    }
}
