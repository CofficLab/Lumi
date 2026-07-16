import CoreGraphics
import LumiCoreKit
import SwiftUI
import Combine

/// 布局持久化锚点视图
///
/// 挂载到 RootOverlay 上，负责：
/// 1. 实例化时开始监听内核发出的布局变更事件
///
/// 布局恢复由 `LayoutPlugin.lifecycle(.appDidLaunch)` 统一触发，
/// 不在此处重复调用，避免双恢复点。
struct LayoutRootView: View {
    let content: AnyView
    @StateObject private var listener: LayoutEventListener

    init(content: AnyView) {
        self.content = content
        self._listener = StateObject(wrappedValue: LayoutEventListener())
    }

    var body: some View {
        content
    }
}

/// 布局事件监听器
///
/// 使用 Combine 订阅 `NotificationCenter` 事件，
/// 实例化即开始监听，不依赖视图挂载。
@MainActor
final class LayoutEventListener: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let store: LayoutPluginLocalStore

    /// - Parameter store: 落盘目标，默认为共享单例（生产环境）。
    init(store: LayoutPluginLocalStore = .shared) {
        self.store = store
        if LayoutPlugin.verbose {
            LayoutPlugin.logger.info("\(LayoutPlugin.t)开始监听布局变更事件")
        }

        NotificationCenter.default.publisher(for: .activeViewContainerIDDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeViewContainerID → \(containerID)")
                }
                store.saveActiveViewContainerID(containerID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .activeRailTabIDDidChange)
            .sink { notification in
                guard let railTabID = notification.userInfo?["railTabID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeRailTabID → \(railTabID)")
                }
                store.saveSelectedAgentSidebarTabId(railTabID)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .activeBottomTabIDDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let bottomTabID = notification.userInfo?["bottomTabID"] as? String
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeBottomTabID[\(containerID)] → \(bottomTabID)")
                }
                let key = LayoutStorageKey.bottomTabID(viewContainerID: containerID)
                store.saveBottomTabID(bottomTabID, forKey: key)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .bottomPanelVisibleDidChange)
            .sink { notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: bottomPanelVisible → \(visible)")
                }
                store.saveBottomPanelVisible(visible)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .chatSectionVisibleDidChange)
            .sink { notification in
                guard let visible = notification.userInfo?["visible"] as? Bool else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: chatSectionVisible → \(visible)")
                }
                store.set(visible, forKey: LayoutStorageKey.chatSectionVisible)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .railDividerDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let position = LayoutEventPayload.cgFloat(from: notification.userInfo?["position"])
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: railDivider[\(containerID)] → \(position)")
                }
                let key = LayoutStorageKey.railDivider(viewContainerID: containerID)
                store.saveSplitDimension(Double(position), forKey: key)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .chatSectionDividerDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let layoutSuffix = notification.userInfo?["layout"] as? String,
                      let position = LayoutEventPayload.cgFloat(from: notification.userInfo?["position"])
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: chatSectionDivider[\(containerID).\(layoutSuffix)] → \(position)")
                }
                // 还原布局档位枚举以复用 LayoutStorageKey 的 key 生成逻辑
                let layout = LumiChatSectionLayout.from(persistenceKeySuffix: layoutSuffix) ?? .narrow
                let key = LayoutStorageKey.chatSectionDivider(viewContainerID: containerID, layout: layout)
                store.saveSplitDimension(Double(position), forKey: key)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .bottomPanelDividerDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let position = LayoutEventPayload.cgFloat(from: notification.userInfo?["position"])
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: bottomPanelDivider[\(containerID)] → \(position)")
                }
                let key = LayoutStorageKey.bottomPanelDivider(viewContainerID: containerID)
                store.saveSplitDimension(Double(position), forKey: key)
            }
            .store(in: &cancellables)
    }
}
