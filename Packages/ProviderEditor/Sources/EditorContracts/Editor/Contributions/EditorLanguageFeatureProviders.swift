import Foundation

// MARK: - 语言功能 Provider 协议族（契约 V2，§10）

/// 语言功能请求的公共上下文（§10：请求统一包含 scope/document/URI/language/revision）。
public struct EditorFeatureRequestContext: Sendable, Equatable {
    /// 目标文档 URI（嵌入编辑器等无文档场景可为 nil）。
    public let uri: URL?

    public let languageID: String

    /// 目标文档当前 revision（无法确定时为 0）。
    public let revision: UInt64

    public init(uri: URL?, languageID: String, revision: UInt64 = 0) {
        self.uri = uri
        self.languageID = languageID
        self.revision = revision
    }
}

// MARK: - Completion

/// 补全条目（中立 DTO；Host 负责与 LSP/内部补全合并去重排序，§9.5）。
public struct EditorCompletionItem: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case text
        case method
        case function
        case constructor
        case field
        case variable
        case `class`
        case `interface`
        case module
        case property
        case unit
        case value
        case `enum`
        case keyword
        case snippet
        case color
        case file
        case reference
        case folder
        case enumMember
        case constant
        case `struct`
        case event
        case `operator`
        case typeParameter
    }

    public let label: String

    /// 插入文本（与 label 不同时为 snippet 形态，由 Host 负责替换）。
    public let insertText: String

    public let detail: String?

    public let kind: Kind

    /// 合并排序权重，越大越靠前。
    public let priority: Int

    public init(
        label: String,
        insertText: String? = nil,
        detail: String? = nil,
        kind: Kind = .text,
        priority: Int = 0
    ) {
        self.label = label
        self.insertText = insertText ?? label
        self.detail = detail
        self.kind = kind
        self.priority = priority
    }
}

/// 补全请求。
public struct EditorCompletionRequest: Sendable {
    public let context: EditorFeatureRequestContext

    /// 光标位置（zero-based UTF-16）。
    public let position: EditorPosition

    /// 已输入的补全前缀（Host 从文档推导）。
    public let prefix: String

    /// 是否处于类型位置（`let x: ` 等，由 Host 语法判定；无法判定为 false）。
    public let isTypeContext: Bool

    public init(
        context: EditorFeatureRequestContext,
        position: EditorPosition,
        prefix: String,
        isTypeContext: Bool
    ) {
        self.context = context
        self.position = position
        self.prefix = prefix
        self.isTypeContext = isTypeContext
    }
}

/// 补全 Provider（§9.5：所有匹配 Provider 并发执行，合并、去重、排序）。
public protocol EditorCompletionProvider: EditorFeatureProvider {
    /// 触发字符（如 `.`）；空集合表示仅手动/前缀触发。
    var triggerCharacters: Set<Character> { get }

    /// 返回补全条目；不应抛错（能力缺失时返回空数组）。
    func completions(for request: EditorCompletionRequest) async -> [EditorCompletionItem]
}

public extension EditorCompletionProvider {
    var triggerCharacters: Set<Character> { [] }
}

// MARK: - Hover

/// Hover 分区（多 Provider 聚合展示，§9.5）。
public struct EditorHoverSection: Hashable, Sendable {
    /// Markdown 内容。
    public let markdown: String

    /// 聚合排序权重。
    public let priority: Int

    /// 聚合去重键（nil 表示不去重）。
    public let dedupeKey: String?

    public init(markdown: String, priority: Int = 0, dedupeKey: String? = nil) {
        self.markdown = markdown
        self.priority = priority
        self.dedupeKey = dedupeKey
    }
}

/// Hover 请求。
public struct EditorHoverRequest: Sendable {
    public let context: EditorFeatureRequestContext

    /// 悬停位置（zero-based UTF-16）。
    public let position: EditorPosition

    /// 位置处的词符号（Host 从文档提取；无法提取为空串）。
    public let symbol: String

    public init(context: EditorFeatureRequestContext, position: EditorPosition, symbol: String) {
        self.context = context
        self.position = position
        self.symbol = symbol
    }
}

/// Hover Provider（§9.5：聚合多个 Provider，按 section 展示）。
public protocol EditorHoverProvider: EditorFeatureProvider {
    func hover(for request: EditorHoverRequest) async -> [EditorHoverSection]
}

// MARK: - URI 寻址编辑（Provider 贡献用）
//
// `EditorWorkspaceEdit` 按宿主私有 `EditorDocumentID` 寻址（Agent/内部流程经
// documents 契约取得）；语言功能 Provider 只持有 URI，故提供 URI 寻址形态，
// 由宿主在应用时解析为已打开文档。

/// 对单个 URI 文档的一组编辑。
public struct EditorURITextEdit: Equatable, Sendable {
    public let uri: URL

    public let edits: [EditorTextEdit]

    public init(uri: URL, edits: [EditorTextEdit]) {
        self.uri = uri
        self.edits = edits
    }
}

// MARK: - Code Action

/// 代码动作条目。
///
/// 执行形态（优先级从上到下，都为空时条目不可执行）：
/// - `edit`：按 documentID 寻址的工作区编辑（Agent/内部流程）。
/// - `textEdits`：按 URI 寻址的文本编辑（语言 Provider；宿主解析为已打开文档）。
/// - `commandID`：路由到编辑器命令系统执行。
public struct EditorCodeActionItem: Equatable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case quickFix
        case refactor
        case refactorExtract
        case refactorInline
        case refactorRewrite
        case source
        case sourceOrganizeImports
    }

    public let id: String

    public let title: String

    public let kind: Kind

    /// 是否为该位置的首选动作（⌘. 默认项）。
    public let isPreferred: Bool

    public let priority: Int

    /// 应用的工作区编辑（documentID 寻址；Agent/内部流程）。
    public let edit: EditorWorkspaceEdit?

    /// URI 寻址的文本编辑（语言 Provider 形态）。
    public let textEdits: [EditorURITextEdit]

    /// 命令形态：要执行的命令 id。
    public let commandID: String?

    public init(
        id: String,
        title: String,
        kind: Kind = .quickFix,
        isPreferred: Bool = false,
        priority: Int = 0,
        edit: EditorWorkspaceEdit? = nil,
        textEdits: [EditorURITextEdit] = [],
        commandID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.isPreferred = isPreferred
        self.priority = priority
        self.edit = edit
        self.textEdits = textEdits
        self.commandID = commandID
    }
}

/// 代码动作请求。
public struct EditorCodeActionRequest: Sendable {
    public let context: EditorFeatureRequestContext

    /// 请求位置（zero-based UTF-16）。
    public let position: EditorPosition

    /// 选区（无选区时为单点范围）。
    public let range: EditorRange

    /// 选中文本（无选区为 nil）。
    public let selectedText: String?

    public init(
        context: EditorFeatureRequestContext,
        position: EditorPosition,
        range: EditorRange,
        selectedText: String?
    ) {
        self.context = context
        self.position = position
        self.range = range
        self.selectedText = selectedText
    }
}

/// Code Action Provider（§9.5：合并，按 kind、preferred、priority 排序）。
public protocol EditorCodeActionProvider: EditorFeatureProvider {
    func codeActions(for request: EditorCodeActionRequest) async -> [EditorCodeActionItem]
}

// MARK: - Quick Open

/// Quick Open 条目。
public struct EditorQuickOpenItem: Hashable, Sendable, Identifiable {
    public let id: String

    public let title: String

    public let subtitle: String?

    /// SF Symbol 名。
    public let systemImage: String

    public let badge: String?

    /// 选中后打开的位置（nil 时条目仅展示）。
    public let location: EditorLocation?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String = "doc",
        badge: String? = nil,
        location: EditorLocation? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.badge = badge
        self.location = location
    }
}

/// Quick Open 请求。
public struct EditorQuickOpenRequest: Sendable {
    /// 用户输入的过滤串。
    public let query: String

    /// 活动文档上下文（无文档时 languageID 为空）。
    public let context: EditorFeatureRequestContext

    public init(query: String, context: EditorFeatureRequestContext) {
        self.query = query
        self.context = context
    }
}

/// Quick Open Provider（工作区符号/工程条目等进入统一 Quick Open）。
public protocol EditorQuickOpenProvider: EditorFeatureProvider {
    func quickOpenItems(for request: EditorQuickOpenRequest) async -> [EditorQuickOpenItem]
}
