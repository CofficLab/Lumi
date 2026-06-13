import Foundation

public struct EditorMultiCursorWorkflowResult: Equatable, Sendable {
    public let state: MultiCursorState
    public let session: EditorMultiCursorSearchSession?
    public let warningMessage: String?
    public let logAction: String?
    public let logNote: String?

    public init(
        state: MultiCursorState,
        session: EditorMultiCursorSearchSession?,
        warningMessage: String?,
        logAction: String?,
        logNote: String?
    ) {
        self.state = state
        self.session = session
        self.warningMessage = warningMessage
        self.logAction = logAction
        self.logNote = logNote
    }
}

@MainActor
public final class EditorMultiCursorWorkflowController {
    public init() {}

    public func clearedState(
        currentState: MultiCursorState
    ) -> EditorMultiCursorWorkflowResult {
        EditorMultiCursorWorkflowResult(
            state: EditorMultiCursorStateController.clearSecondary(from: currentState),
            session: nil,
            warningMessage: nil,
            logAction: "clearMultiCursors",
            logNote: nil
        )
    }

    public func primarySelectionState(
        _ selection: MultiCursorSelection,
        currentState: MultiCursorState
    ) -> EditorMultiCursorWorkflowResult {
        EditorMultiCursorWorkflowResult(
            state: EditorMultiCursorStateController.replacingPrimary(in: currentState, with: selection),
            session: nil,
            warningMessage: nil,
            logAction: "setPrimarySelection",
            logNote: nil
        )
    }

    public func setSelectionsResult(
        _ selections: [MultiCursorSelection],
        existingSession: EditorMultiCursorSearchSession?,
        text: NSString?
    ) -> EditorMultiCursorWorkflowResult? {
        guard let first = selections.first else { return nil }
        let state = EditorMultiCursorStateController.state(from: selections)

        if selections.count == 1,
           let text,
           let session = EditorMultiCursorSearchController.collapsedSession(
                from: existingSession,
                singleSelection: first,
                in: text
           ) {
            return EditorMultiCursorWorkflowResult(
                state: state,
                session: session,
                warningMessage: nil,
                logAction: "setSelections",
                logNote: "incomingCount=\(selections.count)"
            )
        }

        return EditorMultiCursorWorkflowResult(
            state: state,
            session: nil,
            warningMessage: nil,
            logAction: "setSelections",
            logNote: "incomingCount=\(selections.count)"
        )
    }

    public func addNextOccurrenceResult(
        from range: NSRange,
        currentState: MultiCursorState,
        existingSession: EditorMultiCursorSearchSession?,
        text: NSString
    ) -> EditorMultiCursorWorkflowResult? {
        let normalized = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard let resolved = EditorMultiCursorSearchController.resolvedContext(
            from: normalized,
            in: text,
            existingSession: existingSession
        ) else {
            return EditorMultiCursorWorkflowResult(
                state: currentState,
                session: existingSession,
                warningMessage: String(localized: "Select text before adding next occurrence", bundle: .module),
                logAction: nil,
                logNote: nil
            )
        }

        let context = resolved.context
        var session = existingSession
        var state = currentState
        var logAction: String?
        let logNote = "query=\(context.query)"

        if resolved.shouldStartSession {
            session = EditorMultiCursorSearchController.session(for: context)
            state = EditorMultiCursorStateController.state(from: [context.baseSelection])
            logAction = "addNextOccurrence.sessionStarted"
        }

        let allMatches = EditorMultiCursorMatcher.ranges(of: context.query, in: text)
        guard !allMatches.isEmpty else {
            return EditorMultiCursorWorkflowResult(
                state: state,
                session: session,
                warningMessage: nil,
                logAction: logAction,
                logNote: logNote
            )
        }

        guard let session else {
            return EditorMultiCursorWorkflowResult(
                state: state,
                session: nil,
                warningMessage: nil,
                logAction: logAction,
                logNote: logNote
            )
        }

        if let candidate = EditorMultiCursorSearchController.nextSelection(
            in: allMatches,
            currentState: state,
            session: session
        ) {
            let updatedState = EditorMultiCursorStateController.addingSelection(candidate, to: state)
            let updatedSession = EditorMultiCursorSearchController.appending(candidate, to: session)
            return EditorMultiCursorWorkflowResult(
                state: updatedState,
                session: updatedSession,
                warningMessage: nil,
                logAction: "addNextOccurrence.added",
                logNote: logNote
            )
        }

        return EditorMultiCursorWorkflowResult(
            state: state,
            session: session,
            warningMessage: String(localized: "No more occurrences found", bundle: .module),
            logAction: logAction,
            logNote: logNote
        )
    }

    public func addAllOccurrencesResult(
        from range: NSRange,
        currentState: MultiCursorState,
        text: NSString
    ) -> EditorMultiCursorWorkflowResult? {
        let normalized = EditorMultiCursorMatcher.normalizedRange(range, in: text)
        guard let context = EditorMultiCursorMatcher.searchContext(from: normalized, in: text) else {
            return EditorMultiCursorWorkflowResult(
                state: currentState,
                session: nil,
                warningMessage: String(localized: "Select text before selecting all occurrences", bundle: .module),
                logAction: nil,
                logNote: nil
            )
        }

        let matches = EditorMultiCursorMatcher.ranges(of: context.query, in: text)
        guard !matches.isEmpty else { return nil }

        return EditorMultiCursorWorkflowResult(
            state: EditorMultiCursorStateController.state(from: matches),
            session: EditorMultiCursorSearchController.session(for: context, matches: matches),
            warningMessage: nil,
            logAction: "addAllOccurrences",
            logNote: "query=\(context.query)"
        )
    }

    public func removeLastOccurrenceResult(
        currentState: MultiCursorState,
        existingSession: EditorMultiCursorSearchSession?
    ) -> EditorMultiCursorWorkflowResult? {
        guard currentState.isEnabled else { return nil }
        guard let session = existingSession else {
            return clearedState(currentState: currentState)
        }
        guard let updatedSession = EditorMultiCursorSearchController.removingLast(from: session) else {
            return clearedState(currentState: currentState)
        }

        return EditorMultiCursorWorkflowResult(
            state: EditorMultiCursorStateController.state(from: updatedSession.history),
            session: updatedSession,
            warningMessage: nil,
            logAction: "removeLastOccurrenceSelection",
            logNote: nil
        )
    }
}
