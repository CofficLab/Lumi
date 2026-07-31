import Combine
import CoreGraphics
import Foundation
import os
import SuperLogKit
import SwiftUI

/// 布局状态信息（轻量级数据结构）
public struct LayoutStateInfo: Sendable, Codable {
    public var activeViewContainerID: String?
    public var chatSectionVisible: Bool
    public var railVisible: Bool
    public var contentVisible: Bool
    public var panelVisible: Bool
    public var panelBottomVisible: Bool

    /// 每个 ViewContainer 上次选中的侧边栏 Rail Tab（键为容器 ID，值为 tab ID）
    public var activeRailTabIDs: [String: String]
    /// 每个 ViewContainer 上次选中的底部面板 Tab（键为容器 ID，值为 tab ID）
    public var activeBottomTabIDs: [String: String]
    /// 每个 ViewContainer 用户手动调整过的可见性（键为容器 ID）。
    /// `nil` 字段表示用户未调整该开关，解析时回退到容器声明或全局默认。
    public var visibilityOverrides: [String: VisibilityFlags]

    public init(
        activeViewContainerID: String? = nil,
        chatSectionVisible: Bool = true,
        railVisible: Bool = true,
        contentVisible: Bool = true,
        panelVisible: Bool = true,
        panelBottomVisible: Bool = true,
        activeRailTabIDs: [String: String] = [:],
        activeBottomTabIDs: [String: String] = [:],
        visibilityOverrides: [String: VisibilityFlags] = [:]
    ) {
        self.activeViewContainerID = activeViewContainerID
        self.chatSectionVisible = chatSectionVisible
        self.railVisible = railVisible
        self.contentVisible = contentVisible
        self.panelVisible = panelVisible
        self.panelBottomVisible = panelBottomVisible
        self.activeRailTabIDs = activeRailTabIDs
        self.activeBottomTabIDs = activeBottomTabIDs
        self.visibilityOverrides = visibilityOverrides
    }

    /// 自定义解码：旧版 `layout-info.json` 不含 tab 字典字段时，以空字典兜底，
    /// 避免历史文件因缺字段解码失败而整体丢失布局。
    private enum CodingKeys: String, CodingKey {
        case activeViewContainerID
        case chatSectionVisible
        case railVisible
        case contentVisible
        case panelVisible
        case panelBottomVisible
        case activeRailTabIDs
        case activeBottomTabIDs
        case visibilityOverrides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.activeViewContainerID = try c.decodeIfPresent(String.self, forKey: .activeViewContainerID)
        self.chatSectionVisible = try c.decodeIfPresent(Bool.self, forKey: .chatSectionVisible) ?? true
        self.railVisible = try c.decodeIfPresent(Bool.self, forKey: .railVisible) ?? true
        self.contentVisible = try c.decodeIfPresent(Bool.self, forKey: .contentVisible) ?? true
        self.panelVisible = try c.decodeIfPresent(Bool.self, forKey: .panelVisible) ?? true
        self.panelBottomVisible = try c.decodeIfPresent(Bool.self, forKey: .panelBottomVisible) ?? true
        self.activeRailTabIDs = try c.decodeIfPresent([String: String].self, forKey: .activeRailTabIDs) ?? [:]
        self.activeBottomTabIDs = try c.decodeIfPresent([String: String].self, forKey: .activeBottomTabIDs) ?? [:]
        self.visibilityOverrides = try c.decodeIfPresent([String: VisibilityFlags].self, forKey: .visibilityOverrides) ?? [:]
    }
}

/// 某个 ViewContainer 用户手动调整过的可见性覆盖值。
///
/// 全部为可选：`nil` 表示用户未对该开关做调整，解析时回退到容器声明或全局默认。
public struct VisibilityFlags: Codable, Sendable {
    public var isRailVisible: Bool?
    public var isChatVisible: Bool?
    public var isContentVisible: Bool?
    public var isPanelVisible: Bool?
    public var isPanelHeaderVisible: Bool?
    public var isPanelBottomVisible: Bool?

    public init(
        isRailVisible: Bool? = nil,
        isChatVisible: Bool? = nil,
        isContentVisible: Bool? = nil,
        isPanelVisible: Bool? = nil,
        isPanelHeaderVisible: Bool? = nil,
        isPanelBottomVisible: Bool? = nil
    ) {
        self.isRailVisible = isRailVisible
        self.isChatVisible = isChatVisible
        self.isContentVisible = isContentVisible
        self.isPanelVisible = isPanelVisible
        self.isPanelHeaderVisible = isPanelHeaderVisible
        self.isPanelBottomVisible = isPanelBottomVisible
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

    /// 每个 ViewContainer 上次选中的侧边栏 Rail Tab（键为容器 ID，值为 tab ID）。
    /// 对齐底部 tab 的 `activeBottomTabIDs`：同一套 rail tab 在不同容器下各自记忆选中项。
    @Published private var activeRailTabIDs: [String: String] = [:]

    /// 默认 Rail Tab ID，供查询时兜底（实际选中由视图 `ensureValidSelection` 自愈）。
    public static let defaultRailTabID = "explorer"

    /// 查询某容器当前选中的 Rail Tab。
    public func activeRailTabID(for viewContainerID: String) -> String {
        activeRailTabIDs[viewContainerID] ?? Self.defaultRailTabID
    }

    /// 设置某容器选中的 Rail Tab，并发送变更通知。
    public func setActiveRailTabID(_ id: String, for viewContainerID: String) {
        guard activeRailTabIDs[viewContainerID] != id else { return }
        activeRailTabIDs[viewContainerID] = id
        if Self.verbose {
            Self.logger.info("\(Self.t)activeRailTabID[\(viewContainerID)] → \(id)")
        }
        NotificationCenter.postActiveRailTabIDDidChange(containerID: viewContainerID, railTabID: id)
    }

    /// 从磁盘恢复某容器的 Rail Tab（不发送通知）。
    public func restoreActiveRailTabID(_ id: String, for viewContainerID: String) {
        activeRailTabIDs[viewContainerID] = id
    }

    /// 供持久化序列化使用的只读快照。
    public var activeRailTabIDsDictionary: [String: String] { activeRailTabIDs }

    // MARK: - Visibility Overrides (per-container)

    /// 用户手动调整过的可见性覆盖层（键为容器 ID）。
    ///
    /// 解析某容器可见性时的优先级：用户覆盖 > 容器静态声明 > 全局默认(true)。
    /// 这里的值由 `setXxxVisible` / `applyVisibility` 在有激活容器时自动记录。
    @Published private var visibilityOverrides: [String: VisibilityFlags] = [:]

    /// 供持久化序列化使用的只读快照。
    public var visibilityOverridesDictionary: [String: VisibilityFlags] { visibilityOverrides }

    /// 从磁盘恢复覆盖层（不发送通知，启动阶段用）。
    public func restoreVisibilityOverrides(_ overrides: [String: VisibilityFlags]) {
        visibilityOverrides = overrides
    }

    /// 把用户对某开关的调整记录到当前激活容器的覆盖层（若有激活容器）。
    private func recordUserOverride<T>(_ keyPath: WritableKeyPath<VisibilityFlags, T?>, _ value: T) {
        guard let containerID = activeViewContainerID else { return }
        visibilityOverrides[containerID, default: VisibilityFlags()][keyPath: keyPath] = value
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

    /// Panel Header 是否可见
    @Published public var isPanelHeaderVisible: Bool = true

    /// 底部 Panel 底部是否可见
    @Published public var isPanelBottomVisible: Bool = true

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) {
        isRailVisible = visible
        recordUserOverride(\.isRailVisible, visible)
    }

    public func setChatVisible(_ visible: Bool) {
        isChatVisible = visible
        recordUserOverride(\.isChatVisible, visible)
    }

    public func setContentVisible(_ visible: Bool) {
        isContentVisible = visible
        recordUserOverride(\.isContentVisible, visible)
    }

    public func setPanelVisible(_ visible: Bool) {
        isPanelVisible = visible
        recordUserOverride(\.isPanelVisible, visible)
    }

    public func setPanelHeaderVisible(_ visible: Bool) {
        isPanelHeaderVisible = visible
        recordUserOverride(\.isPanelHeaderVisible, visible)
    }

    public func setPanelBottomVisible(_ visible: Bool) {
        isPanelBottomVisible = visible
        recordUserOverride(\.isPanelBottomVisible, visible)
    }

    /// 激活容器并通知观察者，同时按优先级解析可见性。
    ///
    /// 优先级：用户对该容器的覆盖 > 容器静态声明 > 全局默认(true)。
    /// 这样用户手动调整过的设置不会被容器声明覆盖丢失。
    public func activateContainer(id: String) {
        activeViewContainerID = id
        if let container = viewContainer(id: id) {
            applyResolvedVisibility(for: id, container: container)
        }
        for observer in containerObservers {
            observer(id)
        }
    }

    /// 解析某容器的可见性并应用到全局标志（当前激活容器的运行时视图）。
    private func applyResolvedVisibility(for id: String, container: ViewContainerItem) {
        let user = visibilityOverrides[id]
        /// 优先级：用户覆盖 > 容器声明 > 全局默认(true)。
        func resolve(_ userVal: Bool?, _ containerVal: Bool?) -> Bool {
            userVal ?? containerVal ?? true
        }
        isRailVisible = resolve(user?.isRailVisible, container.isRailVisible)
        isChatVisible = resolve(user?.isChatVisible, container.isChatVisible)
        isContentVisible = resolve(user?.isContentVisible, container.isContentVisible)
        isPanelVisible = resolve(user?.isPanelVisible, container.isPanelVisible)
        isPanelHeaderVisible = resolve(user?.isPanelHeaderVisible, container.isPanelHeaderVisible)
        isPanelBottomVisible = resolve(user?.isPanelBottomVisible, container.isPanelBottomVisible)
    }

    /// 批量应用可见性变更，并同步记录到当前激活容器的覆盖层（与 `setXxxVisible` 一致）。
    public func applyVisibility(
        rail: Bool?,
        chat: Bool?,
        content: Bool?,
        panel: Bool?
    ) {
        if let rail {
            isRailVisible = rail
            recordUserOverride(\.isRailVisible, rail)
        }
        if let chat {
            isChatVisible = chat
            recordUserOverride(\.isChatVisible, chat)
        }
        if let content {
            isContentVisible = content
            recordUserOverride(\.isContentVisible, content)
        }
        if let panel {
            isPanelVisible = panel
            recordUserOverride(\.isPanelVisible, panel)
        }
    }

    // MARK: - View Containers

    /// 容器注册表（私有）。视图不直接读它，而是经 `allViewContainers` →
    /// `@Published sortedViewContainers` 拿到排序后的快照。
    /// 重要不变量：任何对 `viewContainers` 的写入都必须随后调用
    /// `updateSortedViewContainers()`，否则视图不会刷新。
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

    /// 供持久化序列化使用的只读快照。
    public var activeBottomTabIDsDictionary: [String: String] { activeBottomTabIDs }

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
        
        if Self.verbose {
            Self.logger.info("\(Self.t)三栏宽度[\(viewContainerID)]: \(parts.joined(separator: ", "))")
        }
    }

    public func presentRailTab(id: String, for viewContainerID: String) {
        setActiveRailTabID(id, for: viewContainerID)
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        setActiveBottomTabID(id, for: viewContainerID)
        bottomPanelFocusGeneration += 1
    }
}
