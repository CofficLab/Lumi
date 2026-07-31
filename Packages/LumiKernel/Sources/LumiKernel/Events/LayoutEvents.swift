import Foundation
import SwiftUI

// MARK: - Layout Notification Names

extension Notification.Name {
    /// 当前激活的视图容器已变更
    /// object: nil
    /// userInfo: ["containerID": String?]
    public static let activeViewContainerIDDidChange = Notification.Name("ActiveViewContainerIDDidChange")

    /// 侧边栏 Rail Tab 已变更（按 ViewContainer 分别记录）
    /// object: nil
    /// userInfo: ["containerID": String, "railTabID": String]
    public static let activeRailTabIDDidChange = Notification.Name("ActiveRailTabIDDidChange")

    /// 底部面板 Tab 已变更（按 ViewContainer 分别记录）
    /// object: nil
    /// userInfo: ["containerID": String, "bottomTabID": String]
    public static let activeBottomTabIDDidChange = Notification.Name("ActiveBottomTabIDDidChange")

    /// 底部面板可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let bottomPanelVisibleDidChange = Notification.Name("BottomPanelVisibleDidChange")

    /// 聊天区可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let chatSectionVisibleDidChange = Notification.Name("ChatSectionVisibleDidChange")

    /// Rail 视图可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let railVisibleDidChange = Notification.Name("RailVisibleDidChange")

    /// 主内容区域可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let contentVisibleDidChange = Notification.Name("ContentVisibleDidChange")

    /// Panel 可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let panelVisibleDidChange = Notification.Name("PanelVisibleDidChange")

    /// 侧边栏 Rail divider 位置已变更
    /// object: nil
    /// userInfo: ["containerID": String, "position": CGFloat]
    public static let railDividerDidChange = Notification.Name("RailDividerDidChange")

    /// 聊天区 divider 位置已变更
    /// object: nil
    /// userInfo: ["containerID": String, "layout": String, "position": CGFloat]
    public static let chatSectionDividerDidChange = Notification.Name("ChatSectionDividerDidChange")

    /// 底部面板 divider 位置已变更
    /// object: nil
    /// userInfo: ["containerID": String, "position": CGFloat]
    public static let bottomPanelDividerDidChange = Notification.Name("BottomPanelDividerDidChange")
}

// MARK: - Layout NotificationCenter Extensions

extension NotificationCenter {
    public static func postActiveViewContainerIDDidChange(containerID: String?) {
        NotificationCenter.default.post(
            name: .activeViewContainerIDDidChange,
            object: nil,
            userInfo: ["containerID": containerID as Any]
        )
    }

    public static func postActiveRailTabIDDidChange(containerID: String, railTabID: String) {
        NotificationCenter.default.post(
            name: .activeRailTabIDDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "railTabID": railTabID]
        )
    }

    public static func postActiveBottomTabIDDidChange(containerID: String, bottomTabID: String) {
        NotificationCenter.default.post(
            name: .activeBottomTabIDDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "bottomTabID": bottomTabID]
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

    public static func postRailVisibleDidChange(visible: Bool) {
        NotificationCenter.default.post(
            name: .railVisibleDidChange,
            object: nil,
            userInfo: ["visible": visible]
        )
    }

    public static func postContentVisibleDidChange(visible: Bool) {
        NotificationCenter.default.post(
            name: .contentVisibleDidChange,
            object: nil,
            userInfo: ["visible": visible]
        )
    }

    public static func postPanelVisibleDidChange(visible: Bool) {
        NotificationCenter.default.post(
            name: .panelVisibleDidChange,
            object: nil,
            userInfo: ["visible": visible]
        )
    }

    public static func postRailDividerDidChange(containerID: String, position: CGFloat) {
        NotificationCenter.default.post(
            name: .railDividerDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "position": position]
        )
    }

    public static func postChatSectionDividerDidChange(
        containerID: String,
        layout: String,
        position: CGFloat
    ) {
        NotificationCenter.default.post(
            name: .chatSectionDividerDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "layout": layout, "position": position]
        )
    }

    public static func postBottomPanelDividerDidChange(containerID: String, position: CGFloat) {
        NotificationCenter.default.post(
            name: .bottomPanelDividerDidChange,
            object: nil,
            userInfo: ["containerID": containerID, "position": position]
        )
    }
}

// MARK: - Layout Event Payload Helper

/// 解析通知 userInfo 数值字段的辅助，兼容 CGFloat / NSNumber / Double。
public enum LayoutEventPayload {
    public static func cgFloat(from value: Any?) -> CGFloat? {
        if let cg = value as? CGFloat { return cg }
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        return nil
    }
}

// MARK: - Layout SwiftUI View Extensions

@MainActor
public extension View {
    /// 监听当前激活视图容器变更
    func onActiveViewContainerIDDidChange(perform action: @escaping (String?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activeViewContainerIDDidChange)) { notification in
            let containerID = notification.userInfo?["containerID"] as? String
            action(containerID)
        }
    }

    /// 监听侧边栏 Rail Tab 变更（containerID, railTabID）
    func onActiveRailTabIDDidChange(perform action: @escaping (String, String) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .activeRailTabIDDidChange)) { notification in
            guard let containerID = notification.userInfo?["containerID"] as? String,
                  let railTabID = notification.userInfo?["railTabID"] as? String
            else { return }
            action(containerID, railTabID)
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
