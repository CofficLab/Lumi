import CoreGraphics
import Foundation

public enum WorkspaceRegionVisibility: String, Codable, Sendable {
    case unsupported, hiddenByDefault, visibleByDefault, alwaysVisible

    public var isSupported: Bool { self != .unsupported }
    public var allowsUserOverride: Bool { self == .hiddenByDefault || self == .visibleByDefault }
    public var defaultIsVisible: Bool { self == .visibleByDefault || self == .alwaysVisible }
    public func resolve(userOverride: Bool?) -> Bool {
        allowsUserOverride ? (userOverride ?? defaultIsVisible) : defaultIsVisible
    }
}

public struct WorkspaceContainer: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let order: Int
    public let supportsProject: Bool
    public let railVisibility: WorkspaceRegionVisibility
    public let chatVisibility: WorkspaceRegionVisibility
    public let panelHeaderVisibility: WorkspaceRegionVisibility
    public let panelBodyVisibility: WorkspaceRegionVisibility
    public let panelBottomVisibility: WorkspaceRegionVisibility

    public init(
        id: String, title: String, systemImage: String, order: Int = 200,
        supportsProject: Bool = false,
        railVisibility: WorkspaceRegionVisibility = .visibleByDefault,
        chatVisibility: WorkspaceRegionVisibility = .visibleByDefault,
        panelHeaderVisibility: WorkspaceRegionVisibility = .visibleByDefault,
        panelBodyVisibility: WorkspaceRegionVisibility = .visibleByDefault,
        panelBottomVisibility: WorkspaceRegionVisibility = .visibleByDefault
    ) {
        self.id = id; self.title = title; self.systemImage = systemImage; self.order = order
        self.supportsProject = supportsProject; self.railVisibility = railVisibility
        self.chatVisibility = chatVisibility; self.panelHeaderVisibility = panelHeaderVisibility
        self.panelBodyVisibility = panelBodyVisibility; self.panelBottomVisibility = panelBottomVisibility
    }
}

public enum WorkspaceChatLayout: String, Codable, Sendable {
    case none, narrow, wide
    public var defaultWidth: CGFloat { self == .wide ? 480 : (self == .narrow ? 320 : 0) }
}

public struct WorkspaceVisibilityOverrides: Codable, Sendable, Equatable {
    public var rail: Bool?
    public var chat: Bool?
    public var panelHeader: Bool?
    public var panelBody: Bool?
    public var panelBottom: Bool?

    public init(rail: Bool? = nil, chat: Bool? = nil, panelHeader: Bool? = nil,
                panelBody: Bool? = nil, panelBottom: Bool? = nil) {
        self.rail = rail; self.chat = chat; self.panelHeader = panelHeader
        self.panelBody = panelBody; self.panelBottom = panelBottom
    }

    private enum CodingKeys: String, CodingKey {
        case rail = "isRailVisible"
        case chat = "isChatVisible"
        case panelHeader = "isPanelHeaderVisible"
        case panelBody = "isPanelBodyVisible"
        case panelBottom = "isPanelBottomVisible"
    }
}

/// Coding keys intentionally match the old LayoutStateInfo/layout-info.json schema.
public struct WorkspaceLayoutSnapshot: Codable, Sendable, Equatable {
    public var activeViewContainerID: String?
    public var chatSectionVisible: Bool
    public var railVisible: Bool
    public var panelBottomVisible: Bool
    public var activeRailTabIDs: [String: String]
    public var activeBottomTabIDs: [String: String]
    public var visibilityOverrides: [String: WorkspaceVisibilityOverrides]
    public var railDividers: [String: CGFloat]
    public var chatSectionDividers: [String: CGFloat]
    public var bottomPanelDividers: [String: CGFloat]

    public init(activeViewContainerID: String? = nil, chatSectionVisible: Bool = true,
                railVisible: Bool = true, panelBottomVisible: Bool = true,
                activeRailTabIDs: [String: String] = [:], activeBottomTabIDs: [String: String] = [:],
                visibilityOverrides: [String: WorkspaceVisibilityOverrides] = [:],
                railDividers: [String: CGFloat] = [:], chatSectionDividers: [String: CGFloat] = [:],
                bottomPanelDividers: [String: CGFloat] = [:]) {
        self.activeViewContainerID = activeViewContainerID; self.chatSectionVisible = chatSectionVisible
        self.railVisible = railVisible; self.panelBottomVisible = panelBottomVisible
        self.activeRailTabIDs = activeRailTabIDs; self.activeBottomTabIDs = activeBottomTabIDs
        self.visibilityOverrides = visibilityOverrides; self.railDividers = railDividers
        self.chatSectionDividers = chatSectionDividers; self.bottomPanelDividers = bottomPanelDividers
    }

    private enum CodingKeys: String, CodingKey {
        case activeViewContainerID, chatSectionVisible, railVisible, panelBottomVisible
        case activeRailTabIDs, activeBottomTabIDs, visibilityOverrides
        case railDividers, chatSectionDividers, bottomPanelDividers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activeViewContainerID = try c.decodeIfPresent(String.self, forKey: .activeViewContainerID)
        chatSectionVisible = try c.decodeIfPresent(Bool.self, forKey: .chatSectionVisible) ?? true
        railVisible = try c.decodeIfPresent(Bool.self, forKey: .railVisible) ?? true
        panelBottomVisible = try c.decodeIfPresent(Bool.self, forKey: .panelBottomVisible) ?? true
        activeRailTabIDs = try c.decodeIfPresent([String: String].self, forKey: .activeRailTabIDs) ?? [:]
        activeBottomTabIDs = try c.decodeIfPresent([String: String].self, forKey: .activeBottomTabIDs) ?? [:]
        visibilityOverrides = try c.decodeIfPresent([String: WorkspaceVisibilityOverrides].self, forKey: .visibilityOverrides) ?? [:]
        railDividers = try c.decodeIfPresent([String: CGFloat].self, forKey: .railDividers) ?? [:]
        chatSectionDividers = try c.decodeIfPresent([String: CGFloat].self, forKey: .chatSectionDividers) ?? [:]
        bottomPanelDividers = try c.decodeIfPresent([String: CGFloat].self, forKey: .bottomPanelDividers) ?? [:]
    }
}
