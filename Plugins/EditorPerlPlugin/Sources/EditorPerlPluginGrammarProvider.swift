import EditorService
import TreeSitterPerl

final class EditorPerlPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "perl",
            bundle: .module,
            languagePointer: { tree_sitter_perl() }
        )
    }
}
