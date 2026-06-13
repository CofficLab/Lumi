import EditorService
import TreeSitterZig

final class EditorZigPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "zig",
            bundle: .module,
            languagePointer: { tree_sitter_zig() }
        )
    }
}
