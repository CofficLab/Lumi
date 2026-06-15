import EditorService
import TreeSitterPHP

final class EditorPHPPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "php",
            bundle: .module,
            languagePointer: { tree_sitter_php() }
        )
    }
}
