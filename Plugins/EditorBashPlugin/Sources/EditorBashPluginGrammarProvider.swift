import EditorService
import TreeSitterBash

final class EditorBashPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "bash",
            bundle: .module,
            languagePointer: { tree_sitter_bash() }
        )
    }
}
