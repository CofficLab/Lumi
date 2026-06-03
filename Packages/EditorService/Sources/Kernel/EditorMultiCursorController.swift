import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

extension EditorMultiCursorController {
    func summaryText(for state: MultiCursorState) -> String {
        let count = state.all.count
        if count <= 1 { return "1" }
        return "\(count)" + String(localized: " cursors", bundle: .module)
    }

    func cursorPositions(
        from selections: [MultiCursorSelection],
        text: String,
        fallbackLine: Int,
        fallbackColumn: Int,
        positionResolver: @escaping (Int, String) -> Position?
    ) -> [CursorPosition] {
        EditorViewStateController.positions(
            from: selections,
            text: text,
            fallbackLine: fallbackLine,
            fallbackColumn: fallbackColumn,
            positionResolver: positionResolver
        ).cursorPositions
    }

    func stateLogMessage(
        action: String,
        selections: [MultiCursorSelection],
        note: String? = nil
    ) -> String {
        let summary = selections.enumerated().map { index, selection in
            "#\(index){loc=\(selection.location),len=\(selection.length)}"
        }.joined(separator: ", ")
        return note.map { "\(action) | \($0) | stateCount=\(selections.count) | [\(summary)]" }
            ?? "\(action) | stateCount=\(selections.count) | [\(summary)]"
    }

    func inputLogMessage(
        action: String,
        textViewSelections: [NSRange],
        note: String? = nil
    ) -> String {
        let rendered = textViewSelections.enumerated().map { index, range in
            "#\(index){\(NSStringFromRange(range))}"
        }.joined(separator: ", ")
        return note.map { "\(action) | \($0) | textViewCount=\(textViewSelections.count) | [\(rendered)]" }
            ?? "\(action) | textViewCount=\(textViewSelections.count) | [\(rendered)]"
    }
}
