import Foundation

@objc(LumiLSPCallHierarchyEditorPlugin)
@MainActor
final class LSPCallHierarchyEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.call-hierarchy"
    let displayName: String = String(localized: "LSP Call Hierarchy", table: "LSPCallHierarchyEditor")
    override var description: String { String(localized: "Shows incoming and outgoing call hierarchy for symbols.", table: "LSPCallHierarchyEditor") }
    let order: Int = 25

    func register(into registry: EditorExtensionRegistry) {
        // Provided via CallHierarchyProvider
    }
}
