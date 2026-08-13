import Foundation
import SwiftUI

extension Notification.Name {
    /// 当前激活的视图容器已变更
    /// object: nil
    /// userInfo: ["containerID": String?]
    public static let activeViewContainerIDDidChange = KernelLumiEvent.activeViewContainerIDDidChange.notificationName

    /// 侧边栏 Rail Tab 已变更（按 ViewContainer 分别记录）
    /// object: nil
    /// userInfo: ["containerID": String, "railTabID": String]
    public static let activeRailTabIDDidChange = KernelLumiEvent.activeRailTabIDDidChange.notificationName

    /// 底部面板 Tab 已变更（按 ViewContainer 分别记录）
    /// object: nil
    /// userInfo: ["containerID": String, "bottomTabID": String]
    public static let activeBottomTabIDDidChange = KernelLumiEvent.activeBottomTabIDDidChange.notificationName

    /// 底部面板可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let bottomPanelVisibleDidChange = KernelLumiEvent.bottomPanelVisibleDidChange.notificationName

    /// 聊天区可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let chatSectionVisibleDidChange = KernelLumiEvent.chatSectionVisibleDidChange.notificationName

    /// Rail 视图可见性已变更
    /// object: nil
    /// userInfo: ["visible": Bool]
    public static let railVisibleDidChange = KernelLumiEvent.railVisibleDidChange.notificationName

    /// 侧边栏 Rail divider 位置已变更
    /// object: nil
    /// userInfo: ["containerID": String, "position": CGFloat]
    public static let railDividerDidChange = KernelLumiEvent.railDividerDidChange.notificationName

    /// 聊天区 divider 位置已变更
    /// object: nil
    /// userInfo: ["containerID": String, "layout": String, "position": CGFloat]
    public static let chatSectionDividerDidChange = KernelLumiEvent.chatSectionDividerDidChange.notificationName

    /// 底部面板 divider 位置已变更
    /// object: nil
    /// userInfo: ["containerID": String, "position": CGFloat]
    public static let bottomPanelDividerDidChange = KernelLumiEvent.bottomPanelDividerDidChange.notificationName

    /// 工作区 UI 贡献清单已变更（标题栏 / 聊天分区 / 状态栏 / 面板 / 菜单栏 /
    /// 根覆盖层 / 视图容器等任一清单注册、注销或全量重建后触发）。
    ///
    /// object: nil
    /// userInfo: nil
    ///
    /// 与 `objectWillChange` 的区别：本事件是**变更完成后**的广播，消费视图
    /// （如 ChatHeaderView）可在 handler 里从 workspace 服务重新拉取自己关心的
    /// 清单快照，由事件驱动刷新。
    public static let workspaceContributionsDidChange = KernelLumiEvent.workspaceContributionsDidChange.notificationName
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

    /// 监听工作区 UI 贡献清单变更（贡献注册 / 注销 / 全量重建后触发）。
    ///
    /// 消费方在 handler 里从 workspace 服务重新拉取自己关心的清单快照，
    /// 由事件驱动刷新。
    func onWorkspaceContributionsDidChange(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .workspaceContributionsDidChange)) { _ in
            action()
        }
    }
}
