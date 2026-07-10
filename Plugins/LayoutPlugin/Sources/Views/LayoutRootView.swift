import CoreGraphics
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
                guard let bottomTabID = notification.userInfo?["bottomTabID"] as? String else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: activeBottomTabID → \(bottomTabID)")
                }
                store.set(bottomTabID, forKey: LayoutStorageKey.activeBottomTabID)
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

        NotificationCenter.default.publisher(for: .railWidthDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let width = LayoutEventListener.cgFloat(from: notification.userInfo?["width"])
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: railWidth[\(containerID)] → \(width)")
                }
                let key = LayoutStorageKey.railWidth(viewContainerID: containerID)
                store.saveSplitDimension(Double(width), forKey: key)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .chatSectionWidthDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let layoutSuffix = notification.userInfo?["layout"] as? String,
                      let width = LayoutEventListener.cgFloat(from: notification.userInfo?["width"])
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: chatSectionWidth[\(containerID).\(layoutSuffix)] → \(width)")
                }
                // 还原布局档位枚举以复用 LayoutStorageKey 的 key 生成逻辑
                let layout = LumiChatSectionLayout.from(persistenceKeySuffix: layoutSuffix) ?? .narrow
                let key = LayoutStorageKey.chatSectionWidth(viewContainerID: containerID, layout: layout)
                store.saveSplitDimension(Double(width), forKey: key)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .bottomPanelHeightDidChange)
            .sink { notification in
                guard let containerID = notification.userInfo?["containerID"] as? String,
                      let height = LayoutEventListener.cgFloat(from: notification.userInfo?["height"])
                else { return }
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)事件: bottomPanelHeight[\(containerID)] → \(height)")
                }
                let key = LayoutStorageKey.bottomPanelHeight(viewContainerID: containerID)
                store.saveSplitDimension(Double(height), forKey: key)
            }
            .store(in: &cancellables)
    }

    /// 从通知 userInfo 的数值中解析 `CGFloat`，兼容 `CGFloat` / `NSNumber` / `Double`。
    private static func cgFloat(from value: Any?) -> CGFloat? {
        if let cg = value as? CGFloat { return cg }
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        return nil
    }
}
