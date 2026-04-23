import Foundation

@objc(LumiLSPWorkspaceSymbolEditorPlugin)
@MainActor
final class LSPWorkspaceSymbolEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.workspace-symbol"
    let displayName: String = String(localized: "LSP Workspace Symbols", table: "LSPWorkspaceSymbolEditor")
    override var description: String { String(localized: "Provides workspace-wide symbol search.", table: "LSPWorkspaceSymbolEditor") }
    let order: Int = 24

    func register(into registry: EditorExtensionRegistry) {
        // Provided via WorkspaceSymbolProvider
    }
}
