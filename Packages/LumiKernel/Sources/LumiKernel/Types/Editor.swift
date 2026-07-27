import Foundation

// MARK: - 主题

/// 编辑器主题元数据
///
/// 描述编辑器语法高亮主题的基本信息，不包含具体的调色板数据。
/// 用于主题列表展示和主题切换。
public struct EditorThemeInfo: Sendable, Equatable, Identifiable {
    /// 主题唯一标识符（如 "xcode-dark"、"monokai"）
    public let id: String

    /// 主题展示名称
    public let displayName: String

    /// 主题图标名称（SF Symbol，可选）
    public let iconName: String?

    /// 是否为深色主题
    public let isDark: Bool

    public init(id: String, displayName: String, iconName: String? = nil, isDark: Bool) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.isDark = isDark
    }
}

// MARK: - 语言描述符

/// 受支持编程语言的元数据，由语言插件注册。
///
/// 此类型从 `EditorLanguageRuntime` 复制到 `LumiKernel`，使内核无需依赖 `EditorLanguageRuntime`
/// 即可定义编辑器扩展契约（见 `EditorPlugin` / `EditorExtensionRegistrar`）。
/// 编辑器侧在桥接时负责在两边的类型之间做转换。
public struct EditorLanguageDescriptor: Sendable, Equatable, Hashable {
    public let languageId: String
    public let displayName: String
    public let fileExtensions: Set<String>
    public let shebangAliases: Set<String>
    public let additionalModelineIds: Set<String>
    public let lineComment: String?
    public let rangeCommentOpen: String?
    public let rangeCommentClose: String?
    /// Tree-sitter grammar id，用于语法高亮（可能与 `languageId` 不同）。
    public let highlightLanguageId: String
    /// LSP language id；无 LSP 服务时为 nil。
    public let lspLanguageId: String?
    /// 需要合并高亮查询的父语法 id（如 cpp → c）。
    public let parentHighlightLanguageId: String?
    /// 除 `highlights` 之外的额外高亮查询文件 stem（如 `highlights-jsx`）。
    public let additionalHighlightStems: Set<String>

    public init(
        languageId: String,
        displayName: String,
        fileExtensions: Set<String>,
        shebangAliases: Set<String> = [],
        additionalModelineIds: Set<String> = [],
        lineComment: String? = nil,
        rangeCommentOpen: String? = nil,
        rangeCommentClose: String? = nil,
        highlightLanguageId: String? = nil,
        lspLanguageId: String? = nil,
        parentHighlightLanguageId: String? = nil,
        additionalHighlightStems: Set<String> = []
    ) {
        self.languageId = languageId
        self.displayName = displayName
        self.fileExtensions = fileExtensions
        self.shebangAliases = shebangAliases
        self.additionalModelineIds = additionalModelineIds
        self.lineComment = lineComment
        self.rangeCommentOpen = rangeCommentOpen
        self.rangeCommentClose = rangeCommentClose
        self.highlightLanguageId = highlightLanguageId ?? languageId
        self.lspLanguageId = lspLanguageId ?? languageId
        self.parentHighlightLanguageId = parentHighlightLanguageId
        self.additionalHighlightStems = additionalHighlightStems
    }

    public var rangeComment: (String, String)? {
        guard let rangeCommentOpen, let rangeCommentClose else { return nil }
        return (rangeCommentOpen, rangeCommentClose)
    }
}

// MARK: - 语法提供器协议

/// 语法提供器协议，由语言插件实现。
///
/// 同样从 `EditorLanguageRuntime` 复制到 `LumiKernel`，避免内核依赖 `EditorLanguageRuntime`。
/// 由于协议是类型身份相关的，编辑器侧通过 `KernelGrammarProviderAdapter`（`EditorService` 内）
/// 将内核版协议实例桥接为编辑器内部消费的协议实例。
public protocol LanguageGrammarProviding: AnyObject {
    var grammarId: String { get }
    func treeSitterLanguage() -> OpaquePointer?
    func highlightQueryURLs() -> [URL]
    func injectionQueryURL() -> URL?
    func localsQueryURL() -> URL?
    func foldsQueryURL() -> URL?
}

public extension LanguageGrammarProviding {
    func injectionQueryURL() -> URL? { nil }
    func localsQueryURL() -> URL? { nil }
    func foldsQueryURL() -> URL? { nil }
}

