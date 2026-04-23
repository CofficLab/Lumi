import Foundation

@objc(LumiLSPDocumentColorEditorPlugin)
@MainActor
final class LSPDocumentColorEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.document-color"
    let displayName: String = String(localized: "LSP Document Colors", table: "LSPDocumentColorEditor")
    override var description: String { String(localized: "Displays color swatches for color literals from the language server.", table: "LSPDocumentColorEditor") }
    let order: Int = 28

    func register(into registry: EditorExtensionRegistry) {
        // Provided via DocumentColorProvider
    }
}
