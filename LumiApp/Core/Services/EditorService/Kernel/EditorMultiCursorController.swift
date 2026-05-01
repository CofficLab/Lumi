import Foundation
import CodeEditSourceEditor
import LanguageServerProtocol

@MainActor
final class EditorMultiCursorController {
    func clearSecondary(from state: MultiCursorState) -> MultiCursorState {
        EditorMultiCursorStateController.clearSecondary(from: state)
    }

    func replacingPrimary(
        in state: MultiCursorState,
        with selection: MultiCursorSelection
    ) -> MultiCursorState {
        EditorMultiCursorStateController.replacingPrimary(in: state, with: selection)
    }

    func state(from selections: [MultiCursorSelection]) -> MultiCursorState {
        EditorMultiCursorStateController.state(from: selections)
    }

    func nsRanges(from state: MultiCursorState) -> [NSRange] {
        state.all.map { NSRange(location: $0.location, length: $0.length) }
    }

    func nsRanges(from selections: [MultiCursorSelection]) -> [NSRange] {
        selections.map { NSRange(location: $0.location, length: $0.length) }
    }

    func collapsedSession(
        from session: EditorMultiCursorSearchSession?,
        singleSelection: MultiCursorSelection,
        in text: NSString
    ) -> EditorMultiCursorSearchSession? {
        EditorMultiCursorSearchController.collapsedSession(
            from: session,
            singleSelection: singleSelection,
            in: text
        )
    }

    func resolvedContext(
        from range: NSRange,
        in text: NSString,
        existingSession: EditorMultiCursorSearchSession?
    ) -> EditorMultiCursorResolvedContext? {
        let normalizedRange = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }
        return EditorMultiCursorSearchController.resolvedContext(
            from: normalizedRange,
            in: text,
            existingSession: existingSession
        )
    }

    func allOccurrencesContext(
        from range: NSRange,
        in text: NSString
    ) -> EditorMultiCursorSearchContext? {
        let normalizedRange = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }
        return EditorMultiCursorMatcher.searchContext(from: normalizedRange, in: text)
    }

    func ranges(of query: String, in text: NSString) -> [MultiCursorSelection] {
        EditorMultiCursorMatcher.ranges(of: query, in: text)
    }

    func startedSession(for context: EditorMultiCursorSearchContext) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchController.session(for: context)
    }

    func allOccurrencesSession(
        for context: EditorMultiCursorSearchContext,
        matches: [MultiCursorSelection]
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchController.session(for: context, matches: matches)
    }

    func nextSelection(
        in matches: [MultiCursorSelection],
        currentState: MultiCursorState,
        session: EditorMultiCursorSearchSession
    ) -> MultiCursorSelection? {
        EditorMultiCursorSearchController.nextSelection(
            in: matches,
            currentState: currentState,
            session: session
        )
    }

    func appending(
        _ selection: MultiCursorSelection,
        to session: EditorMultiCursorSearchSession
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchController.appending(selection, to: session)
    }

    func removingLast(from session: EditorMultiCursorSearchSession) -> EditorMultiCursorSearchSession? {
        EditorMultiCursorSearchController.removingLast(from: session)
    }

    func addingSelection(
        _ selection: MultiCursorSelection,
        to state: MultiCursorState
    ) -> MultiCursorState {
        EditorMultiCursorStateController.addingSelection(selection, to: state)
    }

    func replacementResult(
        text: String,
        selections: [MultiCursorSelection],
        replacement: String
    ) -> (result: MultiCursorEditResult, transaction: EditorTransaction) {
        let result = MultiCursorEditEngine.apply(
            text: text,
            selections: selections,
            operation: .replaceSelection(replacement)
        )
        let transaction = MultiCursorTransactionBuilder.makeTransaction(
            operation: .replaceSelection(replacement),
            selections: selections,
            updatedSelections: result.selections
        )
        return (result, transaction)
    }

    func operationResult(
        text: String,
        selections: [MultiCursorSelection],
        operation: MultiCursorOperation
    ) -> (result: MultiCursorEditResult, transaction: EditorTransaction) {
        let result = MultiCursorEditEngine.apply(
            text: text,
            selections: selections,
            operation: operation
        )

        let transaction: EditorTransaction
        switch operation {
        case .indent, .outdent:
            transaction = EditorTransaction(
                replacements: [
                    .init(
                        range: EditorRange(location: 0, length: (text as NSString).length),
                        text: result.text
                    )
                ],
                updatedSelections: result.selections.map {
                    EditorSelection(
                        range: EditorRange(location: $0.location, length: $0.length)
                    )
                }
            )
        default:
            transaction = MultiCursorTransactionBuilder.makeTransaction(
                operation: operation,
                selections: selections,
                updatedSelections: result.selections
            )
        }
        return (result, transaction)
    }

    func summaryText(for state: MultiCursorState) -> String {
        let count = state.all.count
        if count <= 1 { return "1" }
        return "\(count)" + String(localized: " cursors", table: "LumiEditor")
    }

    func cursorPositions(
        from selections: [MultiCursorSelection],
        text: String,
        fallbackLine: Int,
        fallbackColumn: Int,
        positionResolver: (Int, String) -> Position?
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

    func clearSession() -> EditorMultiCursorSearchSession? {
        nil
    }
}
