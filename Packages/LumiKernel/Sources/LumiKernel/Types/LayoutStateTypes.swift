import Combine
import CoreGraphics
import Foundation
import os
import SuperLogKit
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

/// 解析通知 userInfo 数值字段的辅助，兼容 CGFloat / NSNumber / Double。
public enum LayoutEventPayload {
    public static func cgFloat(from value: Any?) -> CGFloat? {
        if let cg = value as? CGFloat { return cg }
        if let number = value as? NSNumber { return CGFloat(number.doubleValue) }
        if let double = value as? Double { return CGFloat(double) }
        return nil
    }
}

/// 插件声明的工作区可见性偏好
public struct WorkspaceVisibility: Sendable {
    public var rail: Bool?
    public var chat: Bool?
    public var content: Bool?
    public var activityBar: Bool?
    public var panel: Bool?

    public init(
        rail: Bool? = nil,
        chat: Bool? = nil,
        content: Bool? = nil,
        activityBar: Bool? = nil,
        panel: Bool? = nil
    ) {
        self.rail = rail
        self.chat = chat
        self.content = content
        self.activityBar = activityBar
        self.panel = panel
    }

    /// 全部可见
    public static let allVisible = WorkspaceVisibility(
        rail: true, chat: true, content: true, activityBar: true, panel: true
    )

    /// 仅显示 Chat
    public static let chatOnly = WorkspaceVisibility(
        rail: false, chat: true, content: false, activityBar: true, panel: false
    )

    /// 仅显示 Content + Rail
    public static let contentWithRail = WorkspaceVisibility(
        rail: true, chat: false, content: true, activityBar: true, panel: true
    )
}

/// 布局状态信息（轻量级数据结构）
public struct LayoutStateInfo: Sendable, Codable {
    public var activeSectionID: String
    public var activeSectionTitle: String
    public var chatSectionVisible: Bool

    public init(
        activeSectionID: String = "",
        activeSectionTitle: String = "",
        chatSectionVisible: Bool = true
    ) {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
        self.chatSectionVisible = chatSectionVisible
    }
}

/// LumiCore 布局状态管理器
@MainActor
public final class LayoutState: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📐"
    nonisolated static let verbose = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.layout")

    @Published public var activeViewContainerID: String? {
        didSet {
            guard activeViewContainerID != oldValue else { return }
            let value = activeViewContainerID
            if Self.verbose {
                Self.logger.info("\(Self.t)activeViewContainerID → \(value ?? "nil")")
            }
            NotificationCenter.postActiveViewContainerIDDidChange(containerID: value)
        }
    }

    @Published public var chatSectionVisible: Bool = true {
        didSet {
            guard chatSectionVisible != oldValue else { return }
            let value = chatSectionVisible
            if Self.verbose {
                Self.logger.info("\(Self.t)chatSectionVisible → \(value)")
            }
            NotificationCenter.postChatSectionVisibleDidChange(visible: value)
        }
    }

    @Published public var bottomPanelVisible: Bool = true {
        didSet {
            guard bottomPanelVisible != oldValue else { return }
            let value = bottomPanelVisible
            if Self.verbose {
                Self.logger.info("\(Self.t)bottomPanelVisible → \(value)")
            }
            NotificationCenter.postBottomPanelVisibleDidChange(visible: value)
        }
    }

    @Published public var activeRailTabID: String = "explorer" {
        didSet {
            guard activeRailTabID != oldValue else { return }
            let value = activeRailTabID
            if Self.verbose {
                Self.logger.info("\(Self.t)activeRailTabID → \(value)")
            }
            NotificationCenter.postActiveRailTabIDDidChange(railTabID: value)
        }
    }

    // MARK: - Workspace Visibility (merged from WorkspaceStateProviding)

    /// Rail 视图是否可见
    @Published public var isRailVisible: Bool = true
    /// Chat 区域是否可见
    @Published public var isChatVisible: Bool = true
    /// 主内容区域是否可见
    @Published public var isContentVisible: Bool = true
    /// ActivityBar 是否可见
    @Published public var isActivityBarVisible: Bool = true
    /// 底部 Panel 是否可见
    @Published public var isPanelVisible: Bool = true

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) {
        isRailVisible = visible
    }

    public func setChatVisible(_ visible: Bool) {
        isChatVisible = visible
    }

    public func setContentVisible(_ visible: Bool) {
        isContentVisible = visible
    }

    public func setActivityBarVisible(_ visible: Bool) {
        isActivityBarVisible = visible
    }

    public func setPanelVisible(_ visible: Bool) {
        isPanelVisible = visible
    }

    /// 激活容器并通知观察者
    public func activateContainer(id: String) {
        activeViewContainerID = id
        for observer in containerObservers {
            observer(id)
        }
    }

    /// 批量应用可见性变更
    public func applyVisibility(
        rail: Bool?,
        chat: Bool?,
        content: Bool?,
        activityBar: Bool?,
        panel: Bool?
    ) {
        if let rail { isRailVisible = rail }
        if let chat { isChatVisible = chat }
        if let content { isContentVisible = content }
        if let activityBar { isActivityBarVisible = activityBar }
        if let panel { isPanelVisible = panel }
    }

    // MARK: - Container Observers

    private var containerObservers: [(String) -> Void] = []

    public func addContainerObserver(_ observer: @escaping (String) -> Void) {
        containerObservers.append(observer)
    }

    @Published public private(set) var bottomPanelFocusGeneration = 0

    public static let defaultBottomTabID = "editor-bottom-problems"

    @Published private var railDividers: [String: CGFloat] = [:]
    @Published private var chatSectionDividers: [String: CGFloat] = [:]
    @Published private var bottomPanelDividers: [String: CGFloat] = [:]
    @Published private var activeBottomTabIDs: [String: String] = [:]
    @Published private(set) var legacyBottomTabID: String?

    private var panelColumnWidths: [String: CGFloat] = [:]

    private let defaultRailDivider: CGFloat
    private let defaultChatSectionDivider: CGFloat
    private let defaultBottomPanelDivider: CGFloat

    public init(
        defaultRailDivider: CGFloat = 240,
        defaultChatSectionDivider: CGFloat = 320,
        defaultBottomPanelDivider: CGFloat = 400
    ) {
        self.defaultRailDivider = defaultRailDivider
        self.defaultChatSectionDivider = defaultChatSectionDivider
        self.defaultBottomPanelDivider = defaultBottomPanelDivider
    }

    public func railDivider(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        railDividers[viewContainerID] ?? fallback ?? defaultRailDivider
    }

    public func storedRailDivider(for viewContainerID: String) -> CGFloat? {
        railDividers[viewContainerID]
    }

    public func setRailDivider(_ position: CGFloat, for viewContainerID: String) {
        let clamped = position
        guard railDividers[viewContainerID] != clamped else { return }
        railDividers[viewContainerID] = clamped
        if Self.verbose {
            Self.logger.info("\(Self.t)railDivider[\(viewContainerID)] → \(clamped)")
        }
        logThreeColumnWidths(for: viewContainerID)
        NotificationCenter.postRailDividerDidChange(containerID: viewContainerID, position: clamped)
    }

    public func restoreRailDivider(_ position: CGFloat, for viewContainerID: String) {
        railDividers[viewContainerID] = position
    }

    public func chatSectionDivider(
        for viewContainerID: String,
        layout: LumiChatSectionLayout,
        fallback: CGFloat? = nil
    ) -> CGFloat {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)]
            ?? fallback ?? defaultChatSectionDivider
    }

    public func storedChatSectionDivider(
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> CGFloat? {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)]
    }

    public func setChatSectionDivider(
        _ position: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        let key = chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)
        guard chatSectionDividers[key] != position else { return }
        chatSectionDividers[key] = position
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionDivider[\(viewContainerID).\(layout.persistenceKeySuffix)] → \(position)")
        }
        logThreeColumnWidths(for: viewContainerID)
        NotificationCenter.postChatSectionDividerDidChange(
            containerID: viewContainerID,
            layout: layout.persistenceKeySuffix,
            position: position
        )
    }

    public func restoreChatSectionDivider(
        _ position: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)] = position
    }

    public func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        bottomPanelDividers[viewContainerID] ?? fallback ?? defaultBottomPanelDivider
    }

    public func storedBottomPanelDivider(for viewContainerID: String) -> CGFloat? {
        bottomPanelDividers[viewContainerID]
    }

    public func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        guard bottomPanelDividers[viewContainerID] != position else { return }
        bottomPanelDividers[viewContainerID] = position
        if Self.verbose {
            Self.logger.info("\(Self.t)bottomPanelDivider[\(viewContainerID)] → \(position)")
        }
        NotificationCenter.postBottomPanelDividerDidChange(containerID: viewContainerID, position: position)
    }

    public func restoreBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        bottomPanelDividers[viewContainerID] = position
    }

    public func activeBottomTabID(for viewContainerID: String) -> String {
        activeBottomTabIDs[viewContainerID] ?? legacyBottomTabID ?? Self.defaultBottomTabID
    }

    public func setActiveBottomTabID(_ id: String, for viewContainerID: String) {
        guard activeBottomTabIDs[viewContainerID] != id else { return }
        activeBottomTabIDs[viewContainerID] = id
        if Self.verbose {
            Self.logger.info("\(Self.t)activeBottomTabID[\(viewContainerID)] → \(id)")
        }
        NotificationCenter.postActiveBottomTabIDDidChange(containerID: viewContainerID, bottomTabID: id)
    }

    public func restoreActiveBottomTabID(_ id: String, for viewContainerID: String) {
        activeBottomTabIDs[viewContainerID] = id
    }

    public func restoreLegacyBottomTabID(_ id: String) {
        legacyBottomTabID = id
    }

    private func chatSectionDividerKey(
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> String {
        "\(viewContainerID).\(layout.persistenceKeySuffix)"
    }

    public func setPanelColumnWidth(_ width: CGFloat, for viewContainerID: String) {
        guard width > 0 else { return }
        panelColumnWidths[viewContainerID] = width
    }

    public func panelColumnWidth(for viewContainerID: String) -> CGFloat? {
        panelColumnWidths[viewContainerID]
    }

    private func logThreeColumnWidths(for viewContainerID: String) {
        let rail = railDividers[viewContainerID]
        let panel = panelColumnWidths[viewContainerID]
        let middle: CGFloat? = {
            guard let rail, let panel else { return nil }
            return max(0, panel - rail)
        }()
        let chatEntries = chatSectionDividers
            .filter { $0.key.hasPrefix("\(viewContainerID).") }
            .sorted { $0.key < $1.key }
        let chatText: String
        if chatEntries.isEmpty {
            chatText = "n/a"
        } else {
            chatText = chatEntries.map { k, v -> String in
                let suffix = k.replacingOccurrences(of: "\(viewContainerID).", with: "")
                return "\(suffix)=\(String(format: "%.1f", v))"
            }.joined(separator: ",")
        }
        let parts: [String] = [
            rail.map { "rail=\(String(format: "%.1f", $0))" } ?? "rail=n/a",
            middle.map { "middle=\(String(format: "%.1f", $0))" } ?? "middle=n/a",
            "chatDivider=[\(chatText)]",
        ]
        Self.logger.info("\(Self.t)三栏宽度[\(viewContainerID)]: \(parts.joined(separator: ", "))")
    }

    public func presentRailTab(id: String) {
        activeRailTabID = id
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        setActiveBottomTabID(id, for: viewContainerID)
        bottomPanelFocusGeneration += 1
    }
}
