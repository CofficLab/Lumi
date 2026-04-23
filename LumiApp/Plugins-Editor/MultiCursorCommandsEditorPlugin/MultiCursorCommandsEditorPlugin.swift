import Foundation

@objc(LumiMultiCursorCommandsEditorPlugin)
@MainActor
final class MultiCursorCommandsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.editor.multi-cursor-commands"
    let displayName: String = String(localized: "Multi-Cursor Commands", table: "MultiCursorCommandsEditor")
    override var description: String { String(localized: "Adds context menu actions for multi-cursor editing (add next occurrence, select all, clear).", table: "MultiCursorCommandsEditor") }
    let order: Int = 13

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCommandContributor(MultiCursorCommandContributor())
    }
}
