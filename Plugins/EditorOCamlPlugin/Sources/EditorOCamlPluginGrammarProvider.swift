import EditorService
import TreeSitterOCaml

final class EditorOCamlPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "ocaml",
            bundle: .module,
            languagePointer: { tree_sitter_ocaml() }
        )
    }
}
