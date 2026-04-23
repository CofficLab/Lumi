import Foundation

@objc(LumiLSPSheetsEditorPlugin)
@MainActor
final class LSPSheetsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.sheets"
    let displayName: String = String(localized: "LSP Sheets", table: "LSPSheetsEditor")
    override var description: String { String(localized: "Presents LSP sheets such as workspace symbols and call hierarchy.", table: "LSPSheetsEditor") }
    let order: Int = 17

    func register(into registry: EditorExtensionRegistry) {
        registry.registerSheetContributor(LSPSheetContributor())
    }
}
