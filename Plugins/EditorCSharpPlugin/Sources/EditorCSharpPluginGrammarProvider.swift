import EditorService
import TreeSitterCSharp

final class EditorCSharpPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "c-sharp",
            bundle: .module,
            languagePointer: { tree_sitter_c_sharp() }
        )
    }
}
