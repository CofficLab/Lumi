import Foundation

@objc(LumiLSPFoldingRangeEditorPlugin)
@MainActor
final class LSPFoldingRangeEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.folding-range"
    let displayName: String = String(localized: "LSP Folding Ranges", table: "LSPFoldingRangeEditor")
    override var description: String { String(localized: "Provides code folding ranges from the language server.", table: "LSPFoldingRangeEditor") }
    let order: Int = 26

    func register(into registry: EditorExtensionRegistry) {
        // Provided via FoldingRangeProvider
    }
}
