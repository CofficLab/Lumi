import CoreGraphics
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

    /// 侧边栏 Rail 宽度已变更
    /// object: nil
    /// userInfo: ["containerID": String, "width": CGFloat]
    public static let railWidthDidChange = Notification.Name("RailWidthDidChange")

    /// 聊天区宽度已变更
    /// object: nil
    /// userInfo: ["containerID": String, "layout": String, "width": CGFloat]
    public static let chatSectionWidthDidChange = Notification.Name("ChatSectionWidthDidChange")

    /// 底部面板高度已变更
    /// object: nil
    /// userInfo: ["containerID": String, "height": CGFloat]
    public static let bottomPanelHeightDidChange = Notification.Name("BottomPanelHeightDidChange")
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

    public static func postRailWidthDidChange(containerID: String, width: CGFloat) {
        NotificationCenter.default.post(
            name: .railWidthDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "width": width]
        )
    }

    public static func postChatSectionWidthDidChange(
        containerID: String,
        layout: String,
        width: CGFloat
    ) {
        NotificationCenter.default.post(
            name: .chatSectionWidthDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "layout": layout, "width": width]
        )
    }

    public static func postBottomPanelHeightDidChange(containerID: String, height: CGFloat) {
        NotificationCenter.default.post(
            name: .bottomPanelHeightDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "height": height]
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

    /// 监听侧边栏 Rail 宽度变更
    func onRailWidthDidChange(perform action: @escaping (String, CGFloat) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .railWidthDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let width = notification.userInfo?["width"] as? CGFloat
            else { return }
            action(containerID, width)
        }
    }

    /// 监听聊天区宽度变更
    func onChatSectionWidthDidChange(perform action: @escaping (String, String, CGFloat) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .chatSectionWidthDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let layout = notification.userInfo?["layout"] as? String,
                  let width = notification.userInfo?["width"] as? CGFloat
            else { return }
            action(containerID, layout, width)
        }
    }

    /// 监听底部面板高度变更
    func onBottomPanelHeightDidChange(perform action: @escaping (String, CGFloat) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .bottomPanelHeightDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let height = notification.userInfo?["height"] as? CGFloat
            else { return }
            action(containerID, height)
        }
    }
}
