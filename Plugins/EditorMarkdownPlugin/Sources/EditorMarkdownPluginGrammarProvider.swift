import EditorService
import TreeSitterMarkdown
import TreeSitterMarkdownInline

final class EditorMarkdownGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "markdown",
            bundle: .module,
            languagePointer: { tree_sitter_markdown() }
        )
    }
}

final class EditorMarkdownInlineGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "markdown-inline",
            bundle: .module,
            grammarFolderName: "tree-sitter-markdown-inline",
            languagePointer: { tree_sitter_markdown_inline() }
        )
    }
}
