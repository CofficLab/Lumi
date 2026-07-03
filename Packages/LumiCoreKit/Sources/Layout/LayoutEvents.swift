import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    /// 当前激活的视图容器已变更
    /// object: nil
    /// userInfo: ["containerID": String?]
    public static let activeViewContainerIDDidChange = Notification.Name("ActiveViewContainerIDDidChange")

    /// 侧边栏 Rail Tab 已变更
    /// object: nil
    /// userInfo: ["railTabID": String]
    public static let activeRailTabIDDidChange = Notification.Name("ActiveRailTabIDDidChange")

    /// 底部面板 Tab 已变更
    /// object: nil
    /// userInfo: ["bottomTabID": String]
    public static let activeBottomTabIDDidChange = Notification.Name("ActiveBottomTabIDDidChange")

    /// 底部面板可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let bottomPanelVisibleDidChange = Notification.Name("BottomPanelVisibleDidChange")

    /// 聊天区可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let chatSectionVisibleDidChange = Notification.Name("ChatSectionVisibleDidChange")
}

// MARK: - NotificationCenter Extensions

extension NotificationCenter {
    public static func postActiveViewContainerIDDidChange(containerID: String?) {
        NotificationCenter.default.post(
            name: .activeViewContainerIDDidChange,
            object: nil,
            userInfo: ["containerID": containerID as Any]
        )
    }

    public static func postActiveRailTabIDDidChange(railTabID: String) {
        NotificationCenter.default.post(
            name: .activeRailTabIDDidChange,
            object: nil,
            userInfo: ["railTabID": railTabID]
        )
    }

    public static func postActiveBottomTabIDDidChange(bottomTabID: String) {
        NotificationCenter.default.post(
            name: .activeBottomTabIDDidChange,
            object: nil,
            userInfo: ["bottomTabID": bottomTabID]
        )
    }

    public static func postBottomPanelVisibleDidChange(visible: Bool) {
        NotificationCenter.default.post(
            name: .bottomPanelVisibleDidChange,
            object: nil,
            userInfo: ["visible": visible]
        )
    }

    public static func postChatSectionVisibleDidChange(visible: Bool) {
        NotificationCenter.default.post(
            name: .chatSectionVisibleDidChange,
            object: nil,
            userInfo: ["visible": visible]
        )
    }
}

// MARK: - SwiftUI View Helpers

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

    /// 监听底部面板 Tab 变更
    func onActiveBottomTabIDDidChange(perform action: @escaping (String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activeBottomTabIDDidChange)) { notification in
            guard let bottomTabID = notification.userInfo?["bottomTabID"] as? String else { return }
            action(bottomTabID)
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
}
