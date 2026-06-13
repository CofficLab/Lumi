import EditorService
import TreeSitterLua

final class EditorLuaPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "lua",
            bundle: .module,
            languagePointer: { tree_sitter_lua() }
        )
    }
}
