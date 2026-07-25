import Foundation
import SwiftUI

@MainActor
public extension View {
    /// 监听当前激活视图容器变更
    func onActiveViewContainerIDDidChange(perform action: @escaping (String?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activeViewContainerIDDidChange)) { notification in
            let containerID = notification.userInfo?["containerID"] as? String
            action(containerID)
        }
    }

    /// 监听侧边栏 Rail Tab 变更
    func onActiveRailTabIDDidChange(perform action: @escaping (String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activeRailTabIDDidChange)) { notification in
            guard let railTabID = notification.userInfo?["railTabID"] as? String else { return }
            action(railTabID)
        }
    }

    /// 监听底部面板 Tab 变更（containerID, bottomTabID）
    func onActiveBottomTabIDDidChange(perform action: @escaping (String, String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activeBottomTabIDDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let bottomTabID = notification.userInfo?["bottomTabID"] as? String
            else { return }
            action(containerID, bottomTabID)
        }
    }

    /// 监听底部面板可见性变更
    func onBottomPanelVisibleDidChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bottomPanelVisibleDidChange)) { notification in
            guard let visible = notification.userInfo?["visible"] as? Bool else { return }
            action(visible)
        }
    }

    /// 监听聊天区可见性变更
    func onChatSectionVisibleDidChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .chatSectionVisibleDidChange)) { notification in
            guard let visible = notification.userInfo?["visible"] as? Bool else { return }
            action(visible)
        }
    }

    /// 监听 Rail 可见性变更
    func onRailVisibleDidChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .railVisibleDidChange)) { notification in
            guard let visible = notification.userInfo?["visible"] as? Bool else { return }
            action(visible)
        }
    }

    /// 监听主内容区域可见性变更
    func onContentVisibleDidChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .contentVisibleDidChange)) { notification in
            guard let visible = notification.userInfo?["visible"] as? Bool else { return }
            action(visible)
        }
    }

    /// 监听 ActivityBar 可见性变更
    func onActivityBarVisibleDidChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activityBarVisibleDidChange)) { notification in
            guard let visible = notification.userInfo?["visible"] as? Bool else { return }
            action(visible)
        }
    }

    /// 监听 Panel 可见性变更
    func onPanelVisibleDidChange(perform action: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .panelVisibleDidChange)) { notification in
            guard let visible = notification.userInfo?["visible"] as? Bool else { return }
            action(visible)
        }
    }

    /// 监听侧边栏 Rail divider 位置变更
    func onRailDividerDidChange(perform action: @escaping (String, CGFloat) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .railDividerDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let position = LayoutEventPayload.cgFloat(from: notification.userInfo?["position"])
            else { return }
            action(containerID, position)
        }
    }

    /// 监听聊天区 divider 位置变更
    func onChatSectionDividerDidChange(perform action: @escaping (String, String, CGFloat) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .chatSectionDividerDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let layout = notification.userInfo?["layout"] as? String,
                  let position = LayoutEventPayload.cgFloat(from: notification.userInfo?["position"])
            else { return }
            action(containerID, layout, position)
        }
    }

    /// 监听底部面板 divider 位置变更
    func onBottomPanelDividerDidChange(perform action: @escaping (String, CGFloat) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bottomPanelDividerDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let position = LayoutEventPayload.cgFloat(from: notification.userInfo?["position"])
            else { return }
            action(containerID, position)
        }
    }
}
