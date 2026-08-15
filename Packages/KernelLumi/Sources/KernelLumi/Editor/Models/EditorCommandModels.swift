import Foundation

// MARK: - 命令模型

/// 命令参数：有限的、可序列化的参数类型。
public enum EditorCommandArgument: Equatable, Sendable {
    case none
    case bool(Bool)
    case int(Int)
    case string(String)
    case position(EditorPosition)
    case range(EditorRange)
    case documentID(EditorDocumentID)
    case sessionID(EditorSessionID)
    case uri(URL)
}

/// 命令执行上下文快照，供 keybinding 解析和条件命令使用。
public struct EditorCommandContext: Equatable, Sendable {
    /// 当前活动文档摘要（无打开文档为 nil）。
    public let document: EditorDocumentSummary?

    /// 是否在大型文件模式。
    public let largeFileMode: Bool

    /// 工作区是否受信任。
    public let workspaceTrusted: Bool

    public init(
        document: EditorDocumentSummary?,
        largeFileMode: Bool = false,
        workspaceTrusted: Bool = true
    ) {
        self.document = document
        self.largeFileMode = largeFileMode
        self.workspaceTrusted = workspaceTrusted
    }
}

/// 命令在给定上下文中的展示信息（标题、启用态、快捷键提示）。
public struct EditorCommandPresentation: Equatable, Sendable {
    public let id: EditorCommandID

    public let title: String

    public let category: String

    public let isEnabled: Bool

    public let keybindingLabel: String?

    public init(
        id: EditorCommandID,
        title: String,
        category: String = "",
        isEnabled: Bool = true,
        keybindingLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.isEnabled = isEnabled
        self.keybindingLabel = keybindingLabel
    }
}

/// 快捷键（支持 chord：按顺序触发的多段按键）。
public struct EditorKeybinding: Equatable, Hashable, Sendable {
    /// 每段按键的修饰键 + 主键描述（如 `"⌘S"`、`"⌃⇧P", "⌘P"`）。
    public let chords: [String]

    public init(chords: [String]) {
        self.chords = chords
    }

    public init(_ chord: String) {
        self.chords = [chord]
    }

    /// 展示标签。
    public var displayLabel: String {
        chords.joined(separator: " ")
    }
}

// MARK: - 跨包消歧别名

/// `EditorCommandContext`（V2 契约）的消歧别名。
///
/// `EditorKernel` 中已有同名历史类型（含 languageId/hasSelection 等字段），
/// 且被 `EditorService` re-export；需要同时引用两侧的包使用本别名指向 V2 契约类型。
public typealias EditorV2CommandContext = EditorCommandContext
