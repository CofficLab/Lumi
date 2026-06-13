import EditorService
import TreeSitterTOML

final class EditorTOMLPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "toml",
            bundle: .module,
            languagePointer: { tree_sitter_toml() }
        )
    }
}
