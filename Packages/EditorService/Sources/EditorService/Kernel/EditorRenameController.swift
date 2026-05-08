import Foundation
import AppKit
import EditorKernelCore

@MainActor
final class EditorRenameController: EditorRenamePrompting {
    func promptForNewName() -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Rename Symbol", table: EditorHostEnvironment.current.localizationTable)
        alert.informativeText = String(localized: "Enter a new symbol name:", table: EditorHostEnvironment.current.localizationTable)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Rename", table: EditorHostEnvironment.current.localizationTable))
        alert.addButton(withTitle: String(localized: "Cancel", table: EditorHostEnvironment.current.localizationTable))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        input.placeholderString = String(localized: "New name", table: EditorHostEnvironment.current.localizationTable)
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        return EditorRenamePolicy.normalizedProposedName(input.stringValue)
    }

    func cancelledMessage() -> String {
        String(localized: "Rename cancelled", table: EditorHostEnvironment.current.localizationTable)
    }

    func inProgressMessage() -> String {
        String(localized: "Renaming symbol...", table: EditorHostEnvironment.current.localizationTable)
    }

    func failedMessage() -> String {
        String(localized: "Rename failed", table: EditorHostEnvironment.current.localizationTable)
    }

    func notAppliedMessage() -> String {
        String(localized: "Rename not applied", table: EditorHostEnvironment.current.localizationTable)
    }

    func completedMessage(changedFiles: Int) -> String {
        EditorRenamePolicy.completedMessage(
            prefix: String(localized: "Rename completed, updated files:", table: EditorHostEnvironment.current.localizationTable),
            changedFiles: changedFiles
        )
    }
}
