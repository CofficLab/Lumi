import Foundation

// MARK: - 标签与会话

/// 单个编辑器标签（Session）的只读状态。
public struct EditorSessionTab: Equatable, Hashable, Identifiable, Sendable {
    public let id: EditorSessionID

    /// 对应文档。
    public let documentID: EditorDocumentID

    /// 展示标题（通常为文件名）。
    public let title: String

    /// 是否有未保存修改。
    public let isDirty: Bool

    /// 是否置顶。
    public let isPinned: Bool

    /// 是否为预览标签。
    public let isPreview: Bool

    public init(
        id: EditorSessionID,
        documentID: EditorDocumentID,
        title: String,
        isDirty: Bool = false,
        isPinned: Bool = false,
        isPreview: Bool = false
    ) {
        self.id = id
        self.documentID = documentID
        self.title = title
        self.isDirty = isDirty
        self.isPinned = isPinned
        self.isPreview = isPreview
    }
}

/// Editor Group（一组标签 + 一个编辑区）。
public struct EditorGroupState: Equatable, Hashable, Identifiable, Sendable {
    public let id: EditorGroupID

    /// 组内标签（按展示顺序）。
    public let tabs: [EditorSessionTab]

    /// 组内当前激活的 Session（空组为 nil）。
    public let activeSessionID: EditorSessionID?

    public init(id: EditorGroupID, tabs: [EditorSessionTab], activeSessionID: EditorSessionID?) {
        self.id = id
        self.tabs = tabs
        self.activeSessionID = activeSessionID
    }
}

/// 整个编辑器工作台（多 Group）的状态快照。
///
/// 第一阶段 Host 可以只有一个 group，但 DTO 和命令从一开始支持多个 group
/// （见重构方案 §8.3）。
public struct EditorWorkbenchState: Equatable, Sendable {
    /// 全部 group（按布局顺序）。
    public let groups: [EditorGroupState]

    /// 当前激活 group。
    public let activeGroupID: EditorGroupID?

    public init(groups: [EditorGroupState], activeGroupID: EditorGroupID?) {
        self.groups = groups
        self.activeGroupID = activeGroupID
    }

    /// 激活 group 的状态（无 group 时为 nil）。
    public var activeGroup: EditorGroupState? {
        guard let activeGroupID else { return groups.first }
        return groups.first { $0.id == activeGroupID }
    }

    /// 激活 group 中当前激活的标签。
    public var activeTab: EditorSessionTab? {
        guard let group = activeGroup, let activeSessionID = group.activeSessionID else { return nil }
        return group.tabs.first { $0.id == activeSessionID }
    }

    /// 全部标签的展平列表。
    public var allTabs: [EditorSessionTab] {
        groups.flatMap(\.tabs)
    }
}

// MARK: - 关闭与分栏

/// 关闭标签时的未保存修改处理策略。
public enum EditorClosePolicy: Equatable, Sendable {
    /// 有未保存修改时不关闭，抛出/上报需要确认的错误。
    case requireConfirmation

    /// 直接丢弃未保存修改。
    case discardChanges

    /// 关闭前保存。
    case saveFirst
}

/// 分栏方向。
public enum EditorSplitDirection: Equatable, Sendable {
    case horizontal
    case vertical
}
