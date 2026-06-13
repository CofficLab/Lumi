import EditorService
import TreeSitterHaskell

final class EditorHaskellPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "haskell",
            bundle: .module,
            languagePointer: { tree_sitter_haskell() }
        )
    }
}
