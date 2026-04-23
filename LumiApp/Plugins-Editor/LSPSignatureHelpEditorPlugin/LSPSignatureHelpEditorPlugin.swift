import Foundation

@objc(LumiLSPSignatureHelpEditorPlugin)
@MainActor
final class LSPSignatureHelpEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.signature-help"
    let displayName: String = String(localized: "LSP Signature Help", table: "LSPSignatureHelpEditor")
    override var description: String { String(localized: "Shows function signature hints when typing parameters.", table: "LSPSignatureHelpEditor") }
    let order: Int = 23

    func register(into registry: EditorExtensionRegistry) {
        // Provided via SignatureHelpProvider
    }
}
