import EditorService
import TreeSitterDockerfile

final class EditorDockerfilePluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "dockerfile",
            bundle: .module,
            languagePointer: { tree_sitter_dockerfile() }
        )
    }
}
