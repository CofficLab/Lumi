import Foundation

/// Metadata for a supported programming language, registered by language plugins.
public struct EditorLanguageDescriptor: Sendable, Equatable, Hashable {
    public let languageId: String
    public let displayName: String
    public let fileExtensions: Set<String>
    public let shebangAliases: Set<String>
    public let additionalModelineIds: Set<String>
    public let lineComment: String?
    public let rangeCommentOpen: String?
    public let rangeCommentClose: String?
    /// Tree-sitter grammar id used for syntax highlighting (may differ from `languageId`).
    public let highlightLanguageId: String
    /// LSP language id; nil when the language has no LSP server.
    public let lspLanguageId: String?
    /// Optional parent grammar id whose highlight queries should be merged (e.g. cpp → c).
    public let parentHighlightLanguageId: String?
    /// Additional highlight query file stems beyond `highlights` (e.g. `highlights-jsx`).
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
