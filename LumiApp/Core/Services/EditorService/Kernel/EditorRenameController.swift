import Foundation
import AppKit

@MainActor
final class EditorRenameController {
    func promptForNewName() -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Rename Symbol", table: "LumiEditor")
        alert.informativeText = String(localized: "Enter a new symbol name:", table: "LumiEditor")
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Rename", table: "LumiEditor"))
        alert.addButton(withTitle: String(localized: "Cancel", table: "LumiEditor"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        input.placeholderString = String(localized: "New name", table: "LumiEditor")
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        let newName = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return newName.isEmpty ? nil : newName
    }

    func cancelledMessage() -> String {
        String(localized: "Rename cancelled", table: "LumiEditor")
    }

    func inProgressMessage() -> String {
        String(localized: "Renaming symbol...", table: "LumiEditor")
    }

    func failedMessage() -> String {
        String(localized: "Rename failed", table: "LumiEditor")
    }

    func notAppliedMessage() -> String {
        String(localized: "Rename not applied", table: "LumiEditor")
    }

    func completedMessage(changedFiles: Int) -> String {
        String(localized: "Rename completed, updated files:", table: "LumiEditor") + " \(changedFiles)"
    }
}
