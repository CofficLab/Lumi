import Foundation

// MARK: - Diff 模型（契约 V2，Phase 7 §15.5）

/// 单行 diff 条目（中立 DTO；宿主实现映射自内部 diff 引擎）。
public struct EditorDiffLine: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case unchanged
        case added
        case removed
    }

    public let kind: Kind

    /// 旧文本行号（1-based；added 行为 nil）。
    public let oldLineNumber: Int?

    /// 新文本行号（1-based；removed 行为 nil）。
    public let newLineNumber: Int?

    public let content: String

    public init(kind: Kind, oldLineNumber: Int?, newLineNumber: Int?, content: String) {
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.content = content
    }
}

/// 一个 diff hunk：一段连续变更及其上下文。
public struct EditorDiffHunk: Equatable, Sendable, Identifiable {
    /// 稳定标识：`oldStart-newStart-首行内容摘要`。
    public var id: String { "\(oldStart)#\(newStart)#\(changeFingerprint)" }

    /// hunk 首行在旧文本中的行号（1-based；纯新增时指向插入点之后）。
    public let oldStart: Int

    /// hunk 首行在新文本中的行号（1-based）。
    public let newStart: Int

    public let lines: [EditorDiffLine]

    public init(oldStart: Int, newStart: Int, lines: [EditorDiffLine]) {
        self.oldStart = oldStart
        self.newStart = newStart
        self.lines = lines
    }

    /// hunk 是否包含任何变更行。
    public var hasChanges: Bool {
        lines.contains { $0.kind != .unchanged }
    }

    /// 该 hunk 的所有新增行内容。
    public var addedContents: [String] {
        lines.filter { $0.kind == .added }.map(\.content)
    }

    /// 该 hunk 的所有删除行内容。
    public var removedContents: [String] {
        lines.filter { $0.kind == .removed }.map(\.content)
    }

    /// 变更行在**旧文本**中的行范围（1-based 闭区间；纯新增为 nil）。
    public var oldChangeRange: ClosedRange<Int>? {
        let numbers = lines.compactMap { $0.kind == .removed ? $0.oldLineNumber : nil }
        guard let first = numbers.min(), let last = numbers.max() else { return nil }
        return first...last
    }

    /// 变更行在**新文本**中的行范围（1-based 闭区间；纯删除为 nil）。
    public var newChangeRange: ClosedRange<Int>? {
        let numbers = lines.compactMap { $0.kind == .added ? $0.newLineNumber : nil }
        guard let first = numbers.min(), let last = numbers.max() else { return nil }
        return first...last
    }

    private var changeFingerprint: String {
        let removed = removedContents.joined(separator: "\u{1}")
        let added = addedContents.joined(separator: "\u{1}")
        return "\(removed.count)-\(added.count)-\(removed.prefix(16))-\(added.prefix(16))"
    }
}

/// 一次文档级 diff 结果。
public struct EditorDiffDocument: Equatable, Sendable {
    /// 被比较的文档（旧/新状态的同一 URI）。
    public let uri: URL

    public let hunks: [EditorDiffHunk]

    public init(uri: URL, hunks: [EditorDiffHunk]) {
        self.uri = uri
        self.hunks = hunks
    }

    public static func empty(for uri: URL) -> EditorDiffDocument {
        EditorDiffDocument(uri: uri, hunks: [])
    }

    public var isEmpty: Bool { hunks.isEmpty }

    public var addedLineCount: Int {
        hunks.reduce(0) { $0 + $1.addedContents.count }
    }

    public var removedLineCount: Int {
        hunks.reduce(0) { $0 + $1.removedContents.count }
    }
}

// MARK: - 跨包消歧别名

/// Diff 模型（V2 契约）的消歧别名。
///
/// EditorService 同时引用 EditorKernel 的 diff 引擎类型（宿主内部实现）
/// 与本契约 DTO；两侧存在同名类型，未限定名会歧义。
public typealias EditorV2DiffLine = EditorDiffLine
public typealias EditorV2DiffHunk = EditorDiffHunk
public typealias EditorV2DiffDocument = EditorDiffDocument
