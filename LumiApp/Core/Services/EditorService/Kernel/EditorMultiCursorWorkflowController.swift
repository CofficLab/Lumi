import Foundation

struct EditorMultiCursorWorkflowResult {
    let state: MultiCursorState
    let session: EditorMultiCursorSearchSession?
    let warningMessage: String?
    let logAction: String?
    let logNote: String?
}

@MainActor
final class EditorMultiCursorWorkflowController {
    func clearedState(
        currentState: MultiCursorState,
        using controller: EditorMultiCursorController
    ) -> EditorMultiCursorWorkflowResult {
        EditorMultiCursorWorkflowResult(
            state: controller.clearSecondary(from: currentState),
            session: controller.clearSession(),
            warningMessage: nil,
            logAction: "clearMultiCursors",
            logNote: nil
        )
    }

    func primarySelectionState(
        _ selection: MultiCursorSelection,
        currentState: MultiCursorState,
        using controller: EditorMultiCursorController
    ) -> EditorMultiCursorWorkflowResult {
        EditorMultiCursorWorkflowResult(
            state: controller.replacingPrimary(in: currentState, with: selection),
            session: nil,
            warningMessage: nil,
            logAction: "setPrimarySelection",
            logNote: nil
        )
    }

    func setSelectionsResult(
        _ selections: [MultiCursorSelection],
        existingSession: EditorMultiCursorSearchSession?,
        text: NSString?,
        using controller: EditorMultiCursorController
    ) -> EditorMultiCursorWorkflowResult? {
        guard let first = selections.first else { return nil }
        let state = controller.state(from: selections)

        if selections.count == 1,
           let text,
           let session = controller.collapsedSession(
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
            session: controller.clearSession(),
            warningMessage: nil,
            logAction: "setSelections",
            logNote: "incomingCount=\(selections.count)"
        )
    }

    func addNextOccurrenceResult(
        from range: NSRange,
        currentState: MultiCursorState,
        existingSession: EditorMultiCursorSearchSession?,
        text: NSString,
        using controller: EditorMultiCursorController
    ) -> EditorMultiCursorWorkflowResult? {
        guard let resolved = controller.resolvedContext(
            from: range,
            in: text,
            existingSession: existingSession
        ) else {
            return EditorMultiCursorWorkflowResult(
                state: currentState,
                session: existingSession,
                warningMessage: String(localized: "Select text before adding next occurrence", table: "LumiEditor"),
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
            session = controller.startedSession(for: context)
            state = controller.state(from: [context.baseSelection])
            logAction = "addNextOccurrence.sessionStarted"
        }

        let allMatches = controller.ranges(of: context.query, in: text)
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

        if let candidate = controller.nextSelection(
            in: allMatches,
            currentState: state,
            session: session
        ) {
            let updatedState = controller.addingSelection(candidate, to: state)
            let updatedSession = controller.appending(candidate, to: session)
            return EditorMultiCursorWorkflowResult(
                state: updatedState,
                session: updatedSession,
                warningMessage: nil,
                logAction: resolved.shouldStartSession ? "addNextOccurrence.added" : "addNextOccurrence.added",
                logNote: logNote
            )
        }

        return EditorMultiCursorWorkflowResult(
            state: state,
            session: session,
            warningMessage: String(localized: "No more occurrences found", table: "LumiEditor"),
            logAction: logAction,
            logNote: logNote
        )
    }

    func addAllOccurrencesResult(
        from range: NSRange,
        currentState: MultiCursorState,
        text: NSString,
        using controller: EditorMultiCursorController
    ) -> EditorMultiCursorWorkflowResult? {
        guard let context = controller.allOccurrencesContext(from: range, in: text) else {
            return EditorMultiCursorWorkflowResult(
                state: currentState,
                session: nil,
                warningMessage: String(localized: "Select text before selecting all occurrences", table: "LumiEditor"),
                logAction: nil,
                logNote: nil
            )
        }

        let matches = controller.ranges(of: context.query, in: text)
        guard !matches.isEmpty else { return nil }

        return EditorMultiCursorWorkflowResult(
            state: controller.state(from: matches),
            session: controller.allOccurrencesSession(for: context, matches: matches),
            warningMessage: nil,
            logAction: "addAllOccurrences",
            logNote: "query=\(context.query)"
        )
    }

    func removeLastOccurrenceResult(
        currentState: MultiCursorState,
        existingSession: EditorMultiCursorSearchSession?,
        using controller: EditorMultiCursorController
    ) -> EditorMultiCursorWorkflowResult? {
        guard currentState.isEnabled else { return nil }
        guard let session = existingSession else {
            return clearedState(currentState: currentState, using: controller)
        }
        guard let updatedSession = controller.removingLast(from: session) else {
            return clearedState(currentState: currentState, using: controller)
        }

        return EditorMultiCursorWorkflowResult(
            state: controller.state(from: updatedSession.history),
            session: updatedSession,
            warningMessage: nil,
            logAction: "removeLastOccurrenceSelection",
            logNote: nil
        )
    }
}
