import EditorService
import LumiLocalizationKit
import SwiftUI

/// Editor save commands (⌘S).
///
/// Reads the active window's `EditorService` via `@FocusedValue`, so ⌘S triggers
/// save regardless of whether focus is in the sidebar, chat panel, or editor —
/// matching VS Code behavior.
///
/// Note: The editor's internal `CommandRegistry` still retains `builtin.save`
/// (for the command palette), both ultimately call `EditorFileService.saveNow()`.
struct EditorSaveCommands: Commands {
    @FocusedValue(\.activeEditorService) private var editorService: EditorService?

    var body: some Commands {
        // Replace the system default "Save" menu group to ensure the menu item
        // is in the File menu and bound to ⌘S.
        CommandGroup(replacing: .saveItem) {
            Button(String(localized: "Save", bundle: .module)) {
                editorService?.files.saveNow()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(editorService == nil || editorService?.files.hasUnsavedChanges == false)
        }
    }
}
