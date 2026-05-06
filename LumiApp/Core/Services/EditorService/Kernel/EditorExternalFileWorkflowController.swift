import Foundation

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
        EditorExternalFileReloadPolicy.reloadDecision(
            newContent: newContent,
            currentContent: currentContent,
            currentModDate: currentModDate,
            hasUnsavedChanges: hasUnsavedChanges
        )
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
