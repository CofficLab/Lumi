import Foundation

@objc(LumiLSPSelectionRangeEditorPlugin)
@MainActor
final class LSPSelectionRangeEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.selection-range"
    let displayName: String = String(localized: "LSP Selection Ranges", table: "LSPSelectionRangeEditor")
    override var description: String { String(localized: "Provides smart expand/shrink selection via LSP selection ranges.", table: "LSPSelectionRangeEditor") }
    let order: Int = 27

    func register(into registry: EditorExtensionRegistry) {
        // Provided via SelectionRangeProvider
    }
}
