import EditorService
import TreeSitterScala

final class EditorScalaPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "scala",
            bundle: .module,
            languagePointer: { tree_sitter_scala() }
        )
    }
}
