import EditorService
import TreeSitterJavaScript
import TreeSitterTypeScript
import TreeSitterTSX
import TreeSitterJSDoc

final class EditorJSJavaScriptGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "javascript",
            bundle: .module,
            languagePointer: { tree_sitter_javascript() }
        )
    }
}

final class EditorJSXGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "jsx",
            bundle: .module,
            grammarFolderName: "tree-sitter-javascript",
            languagePointer: { tree_sitter_javascript() },
            additionalHighlightStems: ["highlights-jsx"]
        )
    }
}

final class EditorJSTypeScriptGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "typescript",
            bundle: .module,
            languagePointer: { tree_sitter_typescript() }
        )
    }
}

final class EditorJSTsxGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "tsx",
            bundle: .module,
            grammarFolderName: "tree-sitter-typescript",
            languagePointer: { tree_sitter_tsx() }
        )
    }
}

final class EditorJSJSDocGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "jsdoc",
            bundle: .module,
            languagePointer: { tree_sitter_jsdoc() }
        )
    }
}
