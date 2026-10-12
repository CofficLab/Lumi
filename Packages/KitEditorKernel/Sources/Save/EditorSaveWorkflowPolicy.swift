import Foundation

public enum EditorSaveWorkflowPolicy {
    public static func shouldSaveNowIfNeeded(hasUnsavedChanges: Bool) -> Bool {
        hasUnsavedChanges
    }

    public static func shouldRunSaveTask(isSaving: Bool) -> Bool {
        !isSaving
    }
}
