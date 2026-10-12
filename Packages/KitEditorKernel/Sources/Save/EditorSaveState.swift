import Foundation

public enum EditorSaveState: Equatable {
    case idle
    case editing
    case saving
    case saved
    case conflict(String)
    case error(String)

    public var icon: String {
        switch self {
        case .idle: return "checkmark.circle"
        case .editing: return "pencil.circle"
        case .saving: return "arrow.triangle.2.circlepath"
        case .saved: return "checkmark.circle.fill"
        case .conflict: return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
public final class EditorSaveStateController {
    public init() {}

    public func applySaveSuccess(
        content: String,
        markPersistedText: (String) -> Void,
        clearConflict: () -> Void,
        syncSession: () -> Void,
        scheduleSuccessClear: () -> Void,
        notifyDidSave: (_ content: String) -> Void,
        setHasUnsavedChanges: (Bool) -> Void,
        setSaveState: (EditorSaveState) -> Void
    ) {
        markPersistedText(content)
        setHasUnsavedChanges(false)
        clearConflict()
        notifyDidSave(content)
        setSaveState(.saved)
        syncSession()
        scheduleSuccessClear()
    }

    public func applySaveFailure(
        error: Error,
        syncSession: () -> Void,
        scheduleSuccessClear: () -> Void,
        setSaveState: (EditorSaveState) -> Void
    ) {
        setSaveState(.error(EditorStatusMessageCatalog.saveFailed(error.localizedDescription)))
        syncSession()
        scheduleSuccessClear()
    }

    public func applyMissingFileFailure(
        scheduleSuccessClear: () -> Void,
        setSaveState: (EditorSaveState) -> Void
    ) {
        setSaveState(.error(EditorStatusMessageCatalog.fileNotFound()))
        scheduleSuccessClear()
    }
}
