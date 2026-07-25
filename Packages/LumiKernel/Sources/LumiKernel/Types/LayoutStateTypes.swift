import Combine
import CoreGraphics
import Foundation
import os
import SuperLogKit
import SwiftUI

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

    // MARK: - Section Info (moved from LayoutStateInfo)

    /// 当前激活的 Section ID
    @Published public var activeSectionID: String = ""

    /// 当前激活的 Section 标题
    @Published public var activeSectionTitle: String = ""

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
    @Published public var isRailVisible: Bool = true {
        didSet {
            guard isRailVisible != oldValue else { return }
            NotificationCenter.postRailVisibleDidChange(visible: isRailVisible)
        }
    }

    /// Chat 区域是否可见
    @Published public var isChatVisible: Bool = true {
        didSet {
            guard isChatVisible != oldValue else { return }
            // 使用现有的 chatSectionVisible 通知
            NotificationCenter.postChatSectionVisibleDidChange(visible: isChatVisible)
        }
    }

    /// 主内容区域是否可见
    @Published public var isContentVisible: Bool = true {
        didSet {
            guard isContentVisible != oldValue else { return }
            NotificationCenter.postContentVisibleDidChange(visible: isContentVisible)
        }
    }

    /// 底部 Panel 是否可见
    @Published public var isPanelVisible: Bool = true {
        didSet {
            guard isPanelVisible != oldValue else { return }
            NotificationCenter.postPanelVisibleDidChange(visible: isPanelVisible)
        }
    }

    /// 底部 Panel 底部是否可见
    @Published public var isPanelBottomVisible: Bool = true

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

    public func setPanelVisible(_ visible: Bool) {
        isPanelVisible = visible
    }

    public func setPanelBottomVisible(_ visible: Bool) {
        isPanelBottomVisible = visible
    }

    /// 激活容器并通知观察者，同时根据容器配置自动应用可见性
    public func activateContainer(id: String) {
        activeViewContainerID = id
        // 根据容器配置自动应用可见性
        if let container = viewContainer(id: id) {
            activeSectionID = container.id
            activeSectionTitle = container.title
            applyVisibility(
                rail: container.isRailVisible,
                chat: container.isChatVisible,
                content: container.isContentVisible,
                panel: container.isPanelVisible
            )
            if container.isPanelBottomVisible != nil {
                isPanelBottomVisible = container.isPanelBottomVisible!
            }
        }
        for observer in containerObservers {
            observer(id)
        }
    }

    /// 批量应用可见性变更
    public func applyVisibility(
        rail: Bool?,
        chat: Bool?,
        content: Bool?,
        panel: Bool?
    ) {
        if let rail { isRailVisible = rail }
        if let chat { isChatVisible = chat }
        if let content { isContentVisible = content }
        if let panel { isPanelVisible = panel }
    }

    // MARK: - View Containers

    private var viewContainers: [String: ViewContainerItem] = [:]
    private var viewContainerOrder: [String] = []
    @Published private var sortedViewContainers: [ViewContainerItem] = []

    /// 所有视图容器（按 order 排序）
    public var allViewContainers: [ViewContainerItem] {
        sortedViewContainers
    }

    /// 按 ID 查询视图容器
    public func viewContainer(id: String) -> ViewContainerItem? {
        viewContainers[id]
    }

    /// 注册视图容器
    public func registerViewContainer(_ container: ViewContainerItem) {
        guard viewContainers[container.id] == nil else { return }
        viewContainers[container.id] = container
        viewContainerOrder.append(container.id)
        updateSortedViewContainers()
    }

    /// 注销视图容器
    public func unregisterViewContainer(id: String) {
        viewContainers.removeValue(forKey: id)
        viewContainerOrder.removeAll { $0 == id }
        updateSortedViewContainers()
    }

    private func updateSortedViewContainers() {
        sortedViewContainers = viewContainerOrder.compactMap { viewContainers[$0] }
            .sorted { $0.order < $1.order }
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
