import Foundation

@MainActor
final class EditorSaveStateController {
    func applySaveSuccess(
        content: String,
        documentController: EditorDocumentController,
        clearConflict: () -> Void,
        syncSession: () -> Void,
        scheduleSuccessClear: () -> Void,
        setHasUnsavedChanges: (Bool) -> Void,
        setSaveState: (EditorSaveState) -> Void
    ) {
        documentController.markPersistedText(content)
        setHasUnsavedChanges(false)
        clearConflict()
        setSaveState(.saved)
        syncSession()
        scheduleSuccessClear()
    }

    func applySaveFailure(
        error: Error,
        syncSession: () -> Void,
        scheduleSuccessClear: () -> Void,
        setSaveState: (EditorSaveState) -> Void
    ) {
        setSaveState(.error(String(localized: "Save failed", table: "LumiEditor") + ": \(error.localizedDescription)"))
        syncSession()
        scheduleSuccessClear()
    }

    func applyMissingFileFailure(
        scheduleSuccessClear: () -> Void,
        setSaveState: (EditorSaveState) -> Void
    ) {
        setSaveState(.error(String(localized: "File not found", table: "LumiEditor")))
        scheduleSuccessClear()
    }
}
