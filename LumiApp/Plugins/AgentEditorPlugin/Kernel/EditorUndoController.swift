import Foundation

@MainActor
final class EditorUndoController {
    func captureState(
        currentText: String,
        selections: [EditorSelection]
    ) -> EditorUndoState {
        EditorUndoState(text: currentText, selections: selections)
    }

    func recordChange(
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

    func performUndo(
        in manager: EditorUndoManager
    ) -> (state: EditorUndoState, canUndo: Bool, canRedo: Bool)? {
        guard let state = manager.undo() else { return nil }
        return (state, manager.canUndo, manager.canRedo)
    }

    func performRedo(
        in manager: EditorUndoManager
    ) -> (state: EditorUndoState, canUndo: Bool, canRedo: Bool)? {
        guard let state = manager.redo() else { return nil }
        return (state, manager.canUndo, manager.canRedo)
    }

    func reset(in manager: EditorUndoManager) -> (canUndo: Bool, canRedo: Bool) {
        manager.reset()
        return (manager.canUndo, manager.canRedo)
    }
}
