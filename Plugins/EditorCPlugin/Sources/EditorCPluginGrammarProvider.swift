import EditorService
import TreeSitterC

final class EditorCPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "c",
            bundle: .module,
            languagePointer: { tree_sitter_c() }
        )
    }
}
