import EditorService
import TreeSitterRegex

final class EditorRegexPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "regex",
            bundle: .module,
            languagePointer: { tree_sitter_regex() }
        )
    }
}
