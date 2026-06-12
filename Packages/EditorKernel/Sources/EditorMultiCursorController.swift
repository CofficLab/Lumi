import Foundation

@MainActor
public final class EditorMultiCursorController {
    public init() {}

    public func clearSecondary(from state: MultiCursorState) -> MultiCursorState {
        EditorMultiCursorStateController.clearSecondary(from: state)
    }

    public func replacingPrimary(
        in state: MultiCursorState,
        with selection: MultiCursorSelection
    ) -> MultiCursorState {
        EditorMultiCursorStateController.replacingPrimary(in: state, with: selection)
    }

    public func state(from selections: [MultiCursorSelection]) -> MultiCursorState {
        EditorMultiCursorStateController.state(from: selections)
    }

    public func nsRanges(from state: MultiCursorState) -> [NSRange] {
        state.all.map { NSRange(location: $0.location, length: $0.length) }
    }

    public func nsRanges(from selections: [MultiCursorSelection]) -> [NSRange] {
        selections.map { NSRange(location: $0.location, length: $0.length) }
    }

    public func collapsedSession(
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

    public func resolvedContext(
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

    public func allOccurrencesContext(
        from range: NSRange,
        in text: NSString
    ) -> EditorMultiCursorSearchContext? {
        let normalizedRange = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard normalizedRange.location != NSNotFound else { return nil }
        return EditorMultiCursorMatcher.searchContext(from: normalizedRange, in: text)
    }

    public func ranges(of query: String, in text: NSString) -> [MultiCursorSelection] {
        EditorMultiCursorMatcher.ranges(of: query, in: text)
    }

    public func startedSession(for context: EditorMultiCursorSearchContext) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchController.session(for: context)
    }

    public func allOccurrencesSession(
        for context: EditorMultiCursorSearchContext,
        matches: [MultiCursorSelection]
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchController.session(for: context, matches: matches)
    }

    public func nextSelection(
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

    public func appending(
        _ selection: MultiCursorSelection,
        to session: EditorMultiCursorSearchSession
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchController.appending(selection, to: session)
    }

    public func removingLast(from session: EditorMultiCursorSearchSession) -> EditorMultiCursorSearchSession? {
        EditorMultiCursorSearchController.removingLast(from: session)
    }

    public func addingSelection(
        _ selection: MultiCursorSelection,
        to state: MultiCursorState
    ) -> MultiCursorState {
        EditorMultiCursorStateController.addingSelection(selection, to: state)
    }

    public func replacementResult(
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

    public func operationResult(
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

    public func clearSession() -> EditorMultiCursorSearchSession? {
        nil
    }
}
