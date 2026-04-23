import Foundation

@objc(LumiLSPContextCommandsEditorPlugin)
@MainActor
final class LSPContextCommandsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.context-commands"
    let displayName: String = String(localized: "LSP Context Commands", table: "LSPContextCommandsEditor")
    override var description: String { String(localized: "Adds LSP context commands like go to definition and rename.", table: "LSPContextCommandsEditor") }
    let order: Int = 15

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCommandContributor(LSPContextCommandContributor())
    }
}
