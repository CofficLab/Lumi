import Foundation
import CodeEditSourceEditor

struct EditorViewState: Equatable {
    var primaryCursorLine: Int
    var primaryCursorColumn: Int
    var cursorPositions: [CursorPosition]

    init(
        primaryCursorLine: Int = 1,
        primaryCursorColumn: Int = 1,
        cursorPositions: [CursorPosition] = []
    ) {
        self.primaryCursorLine = primaryCursorLine
        self.primaryCursorColumn = primaryCursorColumn
        self.cursorPositions = cursorPositions
    }

    static let initial = EditorViewState()
}
