import Foundation

// MARK: - 文档基础枚举

/// 文档文本编码。
public enum EditorTextEncoding: String, Equatable, Sendable {
    case utf8
    case utf16
    case latin1
}

/// 文档行尾格式。
public enum EditorLineEnding: String, Equatable, Sendable {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"

    /// 当前平台默认行尾。
    public static let platformDefault: EditorLineEnding = .lf
}

/// 大文件策略模式。
public enum EditorLargeFileMode: String, Equatable, Sendable {
    /// 正常模式，所有能力可用。
    case normal

    /// 大文件模式：禁用高耗能力（语义高亮、LSP 增量、minimap 等）。
    case degraded

    /// 超大/二进制文件：只读或拒绝加载完整内容。
    case readOnly
}

// MARK: - 保存原因

/// 触发保存的原因，供 Auto Save 等策略区分用户意图。
public enum EditorSaveReason: Equatable, Sendable {
    /// 用户显式保存（⌘S / 菜单）。
    case explicit

    /// 自动保存（延时/失焦/窗口关闭）。
    case auto

    /// 应用 Workspace Edit 后按策略保存。
    case afterEdit

    /// 关闭前保存。
    case beforeClose
}

// MARK: - 文档 Snapshot

/// 完整文档快照。
///
/// 完整 `text` 只按需获取（`EditorDocumentProviding.snapshot(documentID:)`）；
/// 常规状态订阅使用不含文本的 `EditorDocumentSummary`，
/// 避免每次按键复制整份文档（见重构方案 §7.3）。
public struct EditorDocumentSnapshot: Equatable, Sendable {
    public let id: EditorDocumentID
    public let uri: URL
    public let languageID: String
    /// 文档 revision，单调递增；异步结果据此丢弃 stale 结果。
    public let revision: UInt64
    public let text: String
    public let encoding: EditorTextEncoding
    public let lineEnding: EditorLineEnding
    public let isDirty: Bool
    public let isReadOnly: Bool
    public let largeFileMode: EditorLargeFileMode

    public init(
        id: EditorDocumentID,
        uri: URL,
        languageID: String,
        revision: UInt64,
        text: String,
        encoding: EditorTextEncoding = .utf8,
        lineEnding: EditorLineEnding = .lf,
        isDirty: Bool = false,
        isReadOnly: Bool = false,
        largeFileMode: EditorLargeFileMode = .normal
    ) {
        self.id = id
        self.uri = uri
        self.languageID = languageID
        self.revision = revision
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = isDirty
        self.isReadOnly = isReadOnly
        self.largeFileMode = largeFileMode
    }

    /// 不含完整文本的轻量摘要。
    public var summary: EditorDocumentSummary {
        EditorDocumentSummary(
            id: id,
            uri: uri,
            languageID: languageID,
            revision: revision,
            isDirty: isDirty,
            isReadOnly: isReadOnly,
            largeFileMode: largeFileMode
        )
    }

    // MARK: 位置换算

    /// 每行起点的 UTF-16 偏移（按 `lineEnding` 切行；`lines[0] == 0`）。
    ///
    /// 用于 zero-based 行列与线性偏移互转。空文本返回 `[0]`。
    public var lineStartOffsets: [Int] {
        var offsets: [Int] = [0]
        let separator = lineEnding.rawValue
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: separator, range: searchRange) {
            // UTF-16 distance 对 BMP 外字符同样按 code unit 计数。
            offsets.append(text.utf16.distance(from: text.startIndex, to: found.upperBound))
            searchRange = found.upperBound..<text.endIndex
        }
        return offsets
    }

    /// 位置 → 全文 UTF-16 偏移。行/列越界时返回 nil。
    public func offset(of position: EditorPosition) -> Int? {
        let offsets = lineStartOffsets
        guard position.line >= 0, position.line < offsets.count else { return nil }
        let lineStart = offsets[position.line]
        let lineLength: Int
        if position.line + 1 < offsets.count {
            lineLength = offsets[position.line + 1] - lineStart - lineEnding.utf16Length
        } else {
            lineLength = text.utf16.count - lineStart
        }
        guard position.character >= 0, position.character <= lineLength else { return nil }
        return lineStart + position.character
    }

    /// 全文 UTF-16 偏移 → 位置。越界时返回 nil。
    public func position(atOffset offset: Int) -> EditorPosition? {
        let offsets = lineStartOffsets
        guard offset >= 0, offset <= text.utf16.count else { return nil }
        // 找到最后一个起点 <= offset 的行。
        var line = 0
        for (index, lineStart) in offsets.enumerated() where lineStart <= offset {
            line = index
        }
        return EditorPosition(line: line, character: offset - offsets[line])
    }
}

private extension EditorLineEnding {
    var utf16Length: Int {
        // LF/CR 为 1，CRLF 为 2。
        self == .crlf ? 2 : 1
    }
}

// MARK: - 文档摘要与状态

/// 不含完整文本的文档摘要，用于常规状态广播。
public struct EditorDocumentSummary: Equatable, Hashable, Identifiable, Sendable {
    public let id: EditorDocumentID
    public let uri: URL
    public let languageID: String
    public let revision: UInt64
    public let isDirty: Bool
    public let isReadOnly: Bool
    public let largeFileMode: EditorLargeFileMode

    public init(
        id: EditorDocumentID,
        uri: URL,
        languageID: String,
        revision: UInt64,
        isDirty: Bool,
        isReadOnly: Bool,
        largeFileMode: EditorLargeFileMode
    ) {
        self.id = id
        self.uri = uri
        self.languageID = languageID
        self.revision = revision
        self.isDirty = isDirty
        self.isReadOnly = isReadOnly
        self.largeFileMode = largeFileMode
    }
}

/// 文档集合状态快照（活动文档 + 全部打开文档摘要）。
public struct EditorDocumentState: Equatable, Sendable {
    /// 当前活动文档摘要（无打开文档时为 nil）。
    public let activeDocument: EditorDocumentSummary?

    /// 全部打开文档摘要（按打开顺序）。
    public let documents: [EditorDocumentSummary]

    public init(activeDocument: EditorDocumentSummary?, documents: [EditorDocumentSummary]) {
        self.activeDocument = activeDocument
        self.documents = documents
    }
}

// MARK: - 打开请求

/// 打开文档请求。
public struct EditorOpenRequest: Equatable, Sendable {
    public enum OpenKind: Equatable, Sendable {
        /// 常规打开（激活对应标签）。
        case activate
        /// 预览标签（复用已有 preview tab）。
        case preview
        /// 后台打开（不切换当前激活标签）。
        case background
    }

    public let uri: URL
    public let kind: OpenKind

    public init(uri: URL, kind: OpenKind = .activate) {
        self.uri = uri
        self.kind = kind
    }
}
