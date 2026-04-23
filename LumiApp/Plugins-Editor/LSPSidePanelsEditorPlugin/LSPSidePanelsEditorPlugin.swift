import Foundation

@objc(LumiLSPSidePanelsEditorPlugin)
@MainActor
final class LSPSidePanelsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.side-panels"
    let displayName: String = String(localized: "LSP Side Panels", table: "LSPSidePanelsEditor")
    override var description: String { String(localized: "Provides references and problems side panels.", table: "LSPSidePanelsEditor") }
    let order: Int = 16

    func register(into registry: EditorExtensionRegistry) {
        registry.registerSidePanelContributor(LSPSidePanelContributor())
    }
}
