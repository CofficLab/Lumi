import EditorService
import TreeSitterRust

final class EditorRustPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "rust",
            bundle: .module,
            languagePointer: { tree_sitter_rust() }
        )
    }
}
