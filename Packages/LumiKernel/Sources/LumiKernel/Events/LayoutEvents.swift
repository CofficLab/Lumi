import Foundation
import SwiftUI

// MARK: - Layout Notification Names

extension Notification.Name {
    /// 当前激活的视图容器已变更
    /// object: nil
    /// userInfo: ["containerID": String?]
    public static let activeViewContainerIDDidChange = Notification.Name("ActiveViewContainerIDDidChange")

    /// 侧边栏 Rail Tab 已变更
    /// object: nil
    /// userInfo: ["railTabID": String]
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

    /// ActivityBar 可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let activityBarVisibleDidChange = Notification.Name("ActivityBarVisibleDidChange")

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

    public static func postActiveRailTabIDDidChange(railTabID: String) {
        NotificationCenter.default.post(
            name: .activeRailTabIDDidChange,
            object: nil,
            userInfo: ["railTabID": railTabID]
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

    public static func postActivityBarVisibleDidChange(visible: Bool) {
        NotificationCenter.default.post(
            name: .activityBarVisibleDidChange,
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
