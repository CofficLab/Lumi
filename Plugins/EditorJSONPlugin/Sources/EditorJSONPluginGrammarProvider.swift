import EditorService
import TreeSitterJSON

final class EditorJSONPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "json",
            bundle: .module,
            languagePointer: { tree_sitter_json() }
        )
    }
}
