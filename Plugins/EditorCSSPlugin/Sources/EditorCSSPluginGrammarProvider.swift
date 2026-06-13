import EditorService
import TreeSitterCSS

final class EditorCSSPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "css",
            bundle: .module,
            languagePointer: { tree_sitter_css() }
        )
    }
}
