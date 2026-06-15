import EditorService
import TreeSitterElixir

final class EditorElixirPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "elixir",
            bundle: .module,
            languagePointer: { tree_sitter_elixir() }
        )
    }
}
