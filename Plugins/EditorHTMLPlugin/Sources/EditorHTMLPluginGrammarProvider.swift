import EditorService
import TreeSitterHTML

final class EditorHTMLPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "html",
            bundle: .module,
            languagePointer: { tree_sitter_html() }
        )
    }
}
