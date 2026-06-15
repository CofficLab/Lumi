import EditorService
import TreeSitterYAML

final class EditorYAMLPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "yaml",
            bundle: .module,
            languagePointer: { tree_sitter_yaml() }
        )
    }
}
