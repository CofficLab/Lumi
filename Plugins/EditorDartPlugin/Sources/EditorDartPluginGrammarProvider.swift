import EditorService
import TreeSitterDart

final class EditorDartPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "dart",
            bundle: .module,
            languagePointer: { tree_sitter_dart() }
        )
    }
}
