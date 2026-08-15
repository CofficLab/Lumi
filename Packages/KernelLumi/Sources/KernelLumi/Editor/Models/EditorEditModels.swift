import Foundation

// MARK: - 编辑事务

/// 单条文本编辑：用 `newText` 替换 `range` 内的文本。
public struct EditorTextEdit: Equatable, Sendable {
    public let range: EditorRange

    public let newText: String

    public init(range: EditorRange, newText: String) {
        self.range = range
        self.newText = newText
    }
}

/// 对单个文档的一组编辑。
public struct EditorDocumentEdit: Equatable, Sendable {
    public let documentID: EditorDocumentID

    public let edits: [EditorTextEdit]

    public init(documentID: EditorDocumentID, edits: [EditorTextEdit]) {
        self.documentID = documentID
        self.edits = edits
    }

    /// 编辑是否互不重叠（同一文档内的编辑必须满足此约束，见重构方案 §7.4）。
    ///
    /// 空范围（插入）与其他范围相邻（`end == other.start`）不算重叠。
    public var hasOverlappingEdits: Bool {
        let ranges = edits.map(\.range).map(\.normalized)
        for i in 0..<ranges.count {
            for j in (i + 1)..<ranges.count where ranges[i].overlaps(ranges[j]) {
                return true
            }
        }
        return false
    }

    /// 返回按位置升序排序的编辑副本（确定性应用顺序）。
    public var sortedEdits: [EditorTextEdit] {
        edits.sorted { lhs, rhs in
            lhs.range.normalized.start < rhs.range.normalized.start
        }
    }
}

/// 文件级操作（创建/重命名/删除），需经过 Workspace 权限校验。
public struct EditorFileOperation: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case create
        case rename(to: URL)
        case delete
    }

    public let uri: URL

    public let kind: Kind

    public init(uri: URL, kind: Kind) {
        self.uri = uri
        self.kind = kind
    }
}

/// 跨文档编辑事务（应用前由 Host 生成预览摘要并校验 revision）。
public struct EditorWorkspaceEdit: Equatable, Sendable {
    public let documentEdits: [EditorDocumentEdit]

    public let fileOperations: [EditorFileOperation]

    public init(documentEdits: [EditorDocumentEdit] = [], fileOperations: [EditorFileOperation] = []) {
        self.documentEdits = documentEdits
        self.fileOperations = fileOperations
    }

    public var isEmpty: Bool {
        documentEdits.allSatisfy(\.edits.isEmpty) && fileOperations.isEmpty
    }

    /// 是否存在任何文档内重叠编辑。
    public var hasOverlappingEdits: Bool {
        documentEdits.contains { $0.hasOverlappingEdits }
    }

    /// 人类可读的预览摘要（如 "2 files, 5 edits, 1 rename"），供 Diff Review 展示。
    public var summaryDescription: String {
        var parts: [String] = []
        let editCount = documentEdits.reduce(0) { $0 + $1.edits.count }
        if editCount > 0 {
            let fileCount = documentEdits.filter { !$0.edits.isEmpty }.count
            parts.append("\(editCount) edit\(editCount == 1 ? "" : "s") in \(fileCount) file\(fileCount == 1 ? "" : "s")")
        }
        if !fileOperations.isEmpty {
            parts.append("\(fileOperations.count) file operation\(fileOperations.count == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }
}

/// 编辑应用选项（undo 事务与保存策略）。
public struct EditorEditOptions: Equatable, Sendable {
    public let undoStopBefore: Bool

    public let undoStopAfter: Bool

    public let saveAfterApplying: Bool

    /// 展示在撤销菜单中的事务标签。
    public let label: String

    public init(
        undoStopBefore: Bool = true,
        undoStopAfter: Bool = true,
        saveAfterApplying: Bool = false,
        label: String = ""
    ) {
        self.undoStopBefore = undoStopBefore
        self.undoStopAfter = undoStopAfter
        self.saveAfterApplying = saveAfterApplying
        self.label = label
    }
}

/// Workspace Edit 应用结果。
public struct EditorWorkspaceEditResult: Equatable, Sendable {
    /// 成功应用的文档及其新 revision。
    public let appliedDocumentIDs: [EditorDocumentID]

    /// 被拒绝或失败的文档与原因。
    public let failures: [EditorDocumentID: EditorContractError]

    public init(appliedDocumentIDs: [EditorDocumentID], failures: [EditorDocumentID: EditorContractError] = [:]) {
        self.appliedDocumentIDs = appliedDocumentIDs
        self.failures = failures
    }

    public var isCompleteSuccess: Bool {
        failures.isEmpty
    }
}
