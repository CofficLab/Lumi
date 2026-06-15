import EditorService
import TreeSitterRuby

final class EditorRubyPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "ruby",
            bundle: .module,
            languagePointer: { tree_sitter_ruby() }
        )
    }
}
