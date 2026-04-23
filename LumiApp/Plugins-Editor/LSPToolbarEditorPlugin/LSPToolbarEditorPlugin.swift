import Foundation

@objc(LumiLSPToolbarEditorPlugin)
@MainActor
final class LSPToolbarEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.toolbar"
    let displayName: String = String(localized: "LSP Toolbar", table: "LSPToolbarEditor")
    override var description: String { String(localized: "Adds diagnostics, progress, and quick action items to the editor toolbar.", table: "LSPToolbarEditor") }
    let order: Int = 19

    func register(into registry: EditorExtensionRegistry) {
        registry.registerToolbarContributor(LSPToolbarContributor())
    }
}
