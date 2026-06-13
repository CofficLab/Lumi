import EditorService
import TreeSitterJulia

final class EditorJuliaPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "julia",
            bundle: .module,
            languagePointer: { tree_sitter_julia() }
        )
    }
}
