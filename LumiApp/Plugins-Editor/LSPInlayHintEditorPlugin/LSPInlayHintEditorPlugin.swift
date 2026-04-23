import Foundation

@objc(LumiLSPInlayHintEditorPlugin)
@MainActor
final class LSPInlayHintEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.inlay-hint"
    let displayName: String = String(localized: "LSP Inlay Hints", table: "LSPInlayHintEditor")
    override var description: String { String(localized: "Displays type inference and parameter name hints inline.", table: "LSPInlayHintEditor") }
    let order: Int = 22

    func register(into registry: EditorExtensionRegistry) {
        // Provided via InlayHintProvider
    }
}
