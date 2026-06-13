import EditorService
import TreeSitterPython

final class EditorPythonPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "python",
            bundle: .module,
            languagePointer: { tree_sitter_python() }
        )
    }
}
