import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

enum EditorViewStateController {
    static func state(
        line: Int,
        column: Int,
        existingPositions: [CursorPosition],
        preserveCursorSelection: Bool
    ) -> EditorViewState {
        let normalizedLine = max(line, 1)
        let normalizedColumn = max(column, 1)

        guard preserveCursorSelection else {
            return EditorViewState(
                primaryCursorLine: normalizedLine,
                primaryCursorColumn: normalizedColumn,
                cursorPositions: []
            )
        }

        if existingPositions.isEmpty {
            return EditorViewState(
                primaryCursorLine: normalizedLine,
                primaryCursorColumn: normalizedColumn,
                cursorPositions: [
                    CursorPosition(
                        start: .init(line: normalizedLine, column: normalizedColumn),
                        end: nil
                    )
                ]
            )
        }

        var updated = existingPositions
        let existingEnd = updated[0].end
        updated[0] = CursorPosition(
            start: .init(line: normalizedLine, column: normalizedColumn),
            end: existingEnd
        )
        return EditorViewState(
            primaryCursorLine: normalizedLine,
            primaryCursorColumn: normalizedColumn,
            cursorPositions: updated
        )
    }

    static func state(
        from positions: [CursorPosition],
        fallbackLine: Int = EditorViewState.initial.primaryCursorLine,
        fallbackColumn: Int = EditorViewState.initial.primaryCursorColumn
    ) -> EditorViewState {
        if let first = positions.first {
            return EditorViewState(
                primaryCursorLine: max(first.start.line, 1),
                primaryCursorColumn: max(first.start.column, 1),
                cursorPositions: positions
            )
        }

        return EditorViewState(
            primaryCursorLine: fallbackLine,
            primaryCursorColumn: fallbackColumn,
            cursorPositions: positions
        )
    }

    static func positions(
        from selections: [MultiCursorSelection],
        text: String,
        fallbackLine: Int = EditorViewState.initial.primaryCursorLine,
        fallbackColumn: Int = EditorViewState.initial.primaryCursorColumn,
        positionResolver: (Int, String) -> Position?
    ) -> EditorViewState {
        guard !text.isEmpty else {
            return EditorViewState(
                primaryCursorLine: fallbackLine,
                primaryCursorColumn: fallbackColumn,
                cursorPositions: []
            )
        }

        let positions = selections.compactMap { selection -> CursorPosition? in
            guard let start = positionResolver(selection.location, text) else { return nil }
            let endOffset = selection.location + selection.length
            let end = selection.length > 0
                ? positionResolver(endOffset, text)
                : nil

            return CursorPosition(
                start: .init(line: start.line + 1, column: start.character + 1),
                end: end.map { .init(line: $0.line + 1, column: $0.character + 1) }
            )
        }

        if !positions.isEmpty {
            return state(from: positions, fallbackLine: fallbackLine, fallbackColumn: fallbackColumn)
        }

        guard let first = selections.first else {
            return EditorViewState(
                primaryCursorLine: fallbackLine,
                primaryCursorColumn: fallbackColumn,
                cursorPositions: []
            )
        }

        return EditorViewState(
            primaryCursorLine: fallbackLine,
            primaryCursorColumn: fallbackColumn,
            cursorPositions: [
                CursorPosition(
                    start: .init(line: fallbackLine, column: fallbackColumn),
                    end: first.length > 0
                        ? .init(line: fallbackLine, column: fallbackColumn + first.length)
                        : nil
                )
            ]
        )
    }
}
