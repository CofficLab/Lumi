import Foundation
import EditorSource

public struct EditorViewState: Equatable, Sendable {
    public var primaryCursorLine: Int
    public var primaryCursorColumn: Int
    public var cursorPositions: [CursorPosition]

    public init(
        primaryCursorLine: Int = 1,
        primaryCursorColumn: Int = 1,
        cursorPositions: [CursorPosition] = []
    ) {
        self.primaryCursorLine = primaryCursorLine
        self.primaryCursorColumn = primaryCursorColumn
        self.cursorPositions = cursorPositions
    }

    public static let initial = EditorViewState()
}
