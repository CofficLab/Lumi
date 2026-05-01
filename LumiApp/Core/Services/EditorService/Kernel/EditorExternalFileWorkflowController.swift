import Foundation

enum EditorExternalFileReloadDecision {
    case unchanged
    case registerConflict(content: String, modificationDate: Date)
    case applyExternalContent(content: String, modificationDate: Date)
}

@MainActor
final class EditorExternalFileWorkflowController {
    func pollDecision(
        currentModDate: Date,
        hasUnsavedChanges: Bool,
        using controller: EditorExternalFileController
    ) -> Bool {
        controller.shouldReloadForChange(
            currentModDate: currentModDate,
            hasUnsavedChanges: hasUnsavedChanges
        )
    }

    func reloadDecision(
        newContent: String,
        currentContent: String,
        currentModDate: Date,
        hasUnsavedChanges: Bool
    ) -> EditorExternalFileReloadDecision {
        guard newContent != currentContent else { return .unchanged }
        if hasUnsavedChanges {
            return .registerConflict(content: newContent, modificationDate: currentModDate)
        }
        return .applyExternalContent(content: newContent, modificationDate: currentModDate)
    }

    func applyConflictRegistration(
        content: String,
        modificationDate: Date,
        using controller: EditorExternalFileController
    ) -> Bool {
        controller.registerConflictIfNeeded(
            content: content,
            modificationDate: modificationDate
        )
    }
}
