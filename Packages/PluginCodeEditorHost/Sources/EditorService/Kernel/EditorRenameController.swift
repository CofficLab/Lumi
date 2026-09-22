import Foundation
import AppKit
import EditorKernel

@MainActor
final class EditorRenameController: EditorRenamePrompting {
    func promptForNewName() -> String? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Rename Symbol", bundle: .module)
        alert.informativeText = String(localized: "Enter a new symbol name:", bundle: .module)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Rename", bundle: .module))
        alert.addButton(withTitle: String(localized: "Cancel", bundle: .module))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
        input.placeholderString = String(localized: "New name", bundle: .module)
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }

        return EditorRenamePolicy.normalizedProposedName(input.stringValue)
    }

    func cancelledMessage() -> String {
        String(localized: "Rename cancelled", bundle: .module)
    }

    func inProgressMessage() -> String {
        String(localized: "Renaming symbol...", bundle: .module)
    }

    func failedMessage() -> String {
        String(localized: "Rename failed", bundle: .module)
    }

    func notAppliedMessage() -> String {
        String(localized: "Rename not applied", bundle: .module)
    }

    func completedMessage(changedFiles: Int) -> String {
        EditorRenamePolicy.completedMessage(
            prefix: String(localized: "Rename completed, updated files:", bundle: .module),
            changedFiles: changedFiles
        )
    }
}
