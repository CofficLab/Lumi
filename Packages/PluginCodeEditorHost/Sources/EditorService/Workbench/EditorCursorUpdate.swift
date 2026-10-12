import Foundation
import EditorSource

enum EditorCursorUpdate: Equatable {
    case observedPositions([CursorPosition], fallbackLine: Int, fallbackColumn: Int)
    case explicitPositions([CursorPosition], fallbackLine: Int, fallbackColumn: Int)
    case primary(
        line: Int,
        column: Int,
        existingPositions: [CursorPosition],
        preserveCursorSelection: Bool
    )
}
