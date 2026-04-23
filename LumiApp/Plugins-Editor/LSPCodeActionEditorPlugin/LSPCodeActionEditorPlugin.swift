import Foundation

@objc(LumiLSPCodeActionEditorPlugin)
@MainActor
final class LSPCodeActionEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.code-action"
    let displayName: String = String(localized: "LSP Code Actions", table: "LSPCodeActionEditor")
    override var description: String { String(localized: "Provides quick-fix code actions and lightbulb suggestions for diagnostics.", table: "LSPCodeActionEditor") }
    let order: Int = 20

    func register(into registry: EditorExtensionRegistry) {
        // Code actions are provided via CodeActionProvider (injected into EditorState)
        // This plugin serves as the registration entrypoint for the feature.
    }
}
