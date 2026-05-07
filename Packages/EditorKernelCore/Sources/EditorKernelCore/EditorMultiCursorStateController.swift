import Foundation

public enum EditorMultiCursorStateController {
    public static func state(from selections: [MultiCursorSelection]) -> MultiCursorState {
        guard let first = selections.first else {
            return MultiCursorState()
        }

        var state = MultiCursorState()
        state.primary = first
        state.secondary = Array(selections.dropFirst())
        return state
    }

    public static func clearSecondary(from state: MultiCursorState) -> MultiCursorState {
        self.state(from: [state.primary])
    }

    public static func replacingPrimary(
        in state: MultiCursorState,
        with selection: MultiCursorSelection
    ) -> MultiCursorState {
        self.state(from: [selection] + state.secondary)
    }

    public static func addingSelection(
        _ selection: MultiCursorSelection,
        to state: MultiCursorState
    ) -> MultiCursorState {
        var selections = state.all
        if !selections.contains(selection) {
            selections.append(selection)
            selections.sort { $0.location < $1.location }
        }
        return self.state(from: selections)
    }
}
