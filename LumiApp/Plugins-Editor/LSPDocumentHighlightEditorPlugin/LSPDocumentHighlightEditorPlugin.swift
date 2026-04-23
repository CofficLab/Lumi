import Foundation

@objc(LumiLSPDocumentHighlightEditorPlugin)
@MainActor
final class LSPDocumentHighlightEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.document-highlight"
    let displayName: String = String(localized: "LSP Document Highlight", table: "LSPDocumentHighlightEditor")
    override var description: String { String(localized: "Highlights all references of the symbol at cursor position.", table: "LSPDocumentHighlightEditor") }
    let order: Int = 21

    func register(into registry: EditorExtensionRegistry) {
        // Provided via DocumentHighlightProvider
    }
}
