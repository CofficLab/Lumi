import Foundation

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

/// 布局状态现已内联进 `LayoutManager`（`WorkspaceProviding` 的实现类），
/// 不再有独立的 `LayoutState` 类。本文件仅保留供持久化/设置视图使用的轻量 DTO。

