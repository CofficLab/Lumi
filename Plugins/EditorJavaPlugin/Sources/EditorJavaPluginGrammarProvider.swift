import EditorService
import TreeSitterJava

final class EditorJavaPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "java",
            bundle: .module,
            languagePointer: { tree_sitter_java() }
        )
    }
}
