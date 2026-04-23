import Foundation

@objc(LumiLSPDocumentLinkEditorPlugin)
@MainActor
final class LSPDocumentLinkEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.document-link"
    let displayName: String = String(localized: "LSP Document Links", table: "LSPDocumentLinkEditor")
    override var description: String { String(localized: "Makes URLs and file paths clickable in the editor.", table: "LSPDocumentLinkEditor") }
    let order: Int = 29

    func register(into registry: EditorExtensionRegistry) {
        // Provided via DocumentLinkProvider
    }
}
