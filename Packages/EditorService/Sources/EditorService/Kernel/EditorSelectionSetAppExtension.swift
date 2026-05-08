import EditorKernelCore

extension EditorSelectionSet {
    func toMultiCursorState() -> MultiCursorState {
        let mcSelections = toMultiCursorSelections()
        return EditorMultiCursorStateController.state(from: mcSelections)
    }
}
