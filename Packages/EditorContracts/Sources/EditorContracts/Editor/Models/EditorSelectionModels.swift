import Foundation

// MARK: - 选择模型

/// 单个选择（光标或选区）：锚点 + 活动位置。
public struct EditorSelection: Equatable, Hashable, Sendable {
    /// 选区固定端（shift 选择时的起点）。
    public let anchor: EditorPosition

    /// 光标所在端。
    public let active: EditorPosition

    public init(anchor: EditorPosition, active: EditorPosition) {
        self.anchor = anchor
        self.active = active
    }

    /// 单点光标。
    public init(at position: EditorPosition) {
        self.init(anchor: position, active: position)
    }

    /// 规范化后的覆盖范围（`start <= end`）。
    public var range: EditorRange {
        EditorRange(start: anchor, end: active).normalized
    }

    /// 是否为空选择（光标）。
    public var isEmpty: Bool {
        anchor == active
    }
}

/// 选择状态快照（多光标）。
public struct EditorSelectionSnapshot: Equatable, Sendable {
    /// 全部选择（第一个为主选择）。
    public let selections: [EditorSelection]

    /// 所属文档。
    public let documentID: EditorDocumentID

    /// 快照对应的文档 revision。
    public let revision: UInt64

    public init(selections: [EditorSelection], documentID: EditorDocumentID, revision: UInt64) {
        self.selections = selections
        self.documentID = documentID
        self.revision = revision
    }

    /// 主选择（无选择时为 nil）。
    public var primary: EditorSelection? {
        selections.first
    }
}

/// 设置选择后如何滚动 reveal。
public enum EditorRevealPolicy: Equatable, Sendable {
    /// 不滚动。
    case none

    /// 最小滚动让选择可见。
    case minimal

    /// 滚动到视口中央（跳转定义等导航场景）。
    case center
}
