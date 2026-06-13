import Foundation

public struct EditorUndoState: Equatable, Sendable {
    public let text: String
    public let selections: [EditorSelection]

    public init(text: String, selections: [EditorSelection]) {
        self.text = text
        self.selections = selections
    }
}

public final class EditorUndoManager {
    public struct Change: Equatable, Sendable {
        public let before: EditorUndoState
        public let after: EditorUndoState
        public let reason: String

        public init(before: EditorUndoState, after: EditorUndoState, reason: String) {
            self.before = before
            self.after = after
            self.reason = reason
        }
    }

    public private(set) var undoStack: [Change] = []
    public private(set) var redoStack: [Change] = []

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init() {}

    public func recordChange(from before: EditorUndoState, to after: EditorUndoState, reason: String) {
        guard before != after else { return }
        undoStack.append(Change(before: before, after: after, reason: reason))
        redoStack.removeAll()
    }

    public func undo() -> EditorUndoState? {
        guard let change = undoStack.popLast() else { return nil }
        redoStack.append(change)
        return change.before
    }

    public func redo() -> EditorUndoState? {
        guard let change = redoStack.popLast() else { return nil }
        undoStack.append(change)
        return change.after
    }

    public func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
