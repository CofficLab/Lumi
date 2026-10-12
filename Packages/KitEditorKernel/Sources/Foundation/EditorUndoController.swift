import Foundation

@MainActor
public final class EditorUndoController {
    public init() {}

    public func captureState(
        currentText: String,
        selections: [EditorSelection]
    ) -> EditorUndoState {
        EditorUndoState(text: currentText, selections: selections)
    }

    public func recordChange(
        in manager: EditorUndoManager,
        from before: EditorUndoState,
        to after: EditorUndoState,
        reason: String,
        isRestoringUndoState: Bool
    ) -> (canUndo: Bool, canRedo: Bool) {
        guard !isRestoringUndoState else {
            return (manager.canUndo, manager.canRedo)
        }

        manager.recordChange(from: before, to: after, reason: reason)
        return (manager.canUndo, manager.canRedo)
    }

    public func performUndo(
        in manager: EditorUndoManager
    ) -> (state: EditorUndoState, canUndo: Bool, canRedo: Bool)? {
        guard let state = manager.undo() else { return nil }
        return (state, manager.canUndo, manager.canRedo)
    }

    public func performRedo(
        in manager: EditorUndoManager
    ) -> (state: EditorUndoState, canUndo: Bool, canRedo: Bool)? {
        guard let state = manager.redo() else { return nil }
        return (state, manager.canUndo, manager.canRedo)
    }

    public func reset(in manager: EditorUndoManager) -> (canUndo: Bool, canRedo: Bool) {
        manager.reset()
        return (manager.canUndo, manager.canRedo)
    }
}
