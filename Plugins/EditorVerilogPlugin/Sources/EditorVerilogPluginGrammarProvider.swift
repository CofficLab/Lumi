import EditorService
import TreeSitterVerilog

final class EditorVerilogPluginGrammarProvider: BundledGrammarProvider {
    init() {
        super.init(
            grammarId: "verilog",
            bundle: .module,
            languagePointer: { tree_sitter_verilog() }
        )
    }
}
