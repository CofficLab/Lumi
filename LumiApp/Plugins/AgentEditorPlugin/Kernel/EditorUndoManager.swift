import Foundation

struct EditorUndoState: Equatable, Sendable {
    let text: String
    let selections: [EditorSelection]
}

final class EditorUndoManager {
    struct Change: Equatable, Sendable {
        let before: EditorUndoState
        let after: EditorUndoState
        let reason: String
    }

    private(set) var undoStack: [Change] = []
    private(set) var redoStack: [Change] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func recordChange(from before: EditorUndoState, to after: EditorUndoState, reason: String) {
        guard before != after else { return }
        undoStack.append(Change(before: before, after: after, reason: reason))
        redoStack.removeAll()
    }

    func undo() -> EditorUndoState? {
        guard let change = undoStack.popLast() else { return nil }
        redoStack.append(change)
        return change.before
    }

    func redo() -> EditorUndoState? {
        guard let change = redoStack.popLast() else { return nil }
        undoStack.append(change)
        return change.after
    }

    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
