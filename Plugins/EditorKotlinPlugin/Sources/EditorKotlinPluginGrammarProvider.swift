import EditorService
import TreeSitterKotlin

final class EditorKotlinPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "kotlin",
            bundle: .module,
            languagePointer: { tree_sitter_kotlin() }
        )
    }
}
