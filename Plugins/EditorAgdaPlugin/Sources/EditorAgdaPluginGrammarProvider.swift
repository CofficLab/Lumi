import EditorService
import TreeSitterAgda

final class EditorAgdaPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "agda",
            bundle: .module,
            languagePointer: { tree_sitter_agda() }
        )
    }
}
