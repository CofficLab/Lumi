import EditorService
import TreeSitterSQL

final class EditorSQLPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "sql",
            bundle: .module,
            languagePointer: { tree_sitter_sql() }
        )
    }
}
