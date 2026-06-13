import EditorService
import TreeSitterGo
import TreeSitterGoMod

enum EditorGoPluginDescriptor {
    static let go = EditorLanguageDescriptor(
        languageId: "go",
        displayName: "Go",
        fileExtensions: ["go"],
        lineComment: "//",
        rangeCommentOpen: "/*",
        rangeCommentClose: "*/",
        highlightLanguageId: "go",
        lspLanguageId: "go"
    )

    static let goMod = EditorLanguageDescriptor(
        languageId: "go-mod",
        displayName: "Go Module",
        fileExtensions: ["mod"],
        lineComment: "//",
        highlightLanguageId: "go-mod",
        lspLanguageId: nil
    )
}

final class EditorGoGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "go",
            bundle: .module,
            languagePointer: { tree_sitter_go() }
        )
    }
}

final class EditorGoModGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "go-mod",
            bundle: .module,
            grammarFolderName: "tree-sitter-go-mod",
            languagePointer: { tree_sitter_gomod() }
        )
    }
}
