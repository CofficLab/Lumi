import Foundation

struct EditorMultiCursorSearchContext: Equatable {
    let baseSelection: MultiCursorSelection
    let query: String
}

struct EditorMultiCursorSearchSession: Equatable {
    let query: String
    let baseSelection: MultiCursorSelection
    var history: [MultiCursorSelection]
}

struct EditorMultiCursorResolvedContext: Equatable {
    let context: EditorMultiCursorSearchContext
    let shouldStartSession: Bool
}

enum EditorMultiCursorSearchController {
    static func resolvedContext(
        from normalizedRange: NSRange,
        in text: NSString,
        existingSession: EditorMultiCursorSearchSession?
    ) -> EditorMultiCursorResolvedContext? {
        let currentSelectionText = EditorMultiCursorMatcher.selectionText(
            for: normalizedRange,
            in: text
        )

        if let session = existingSession,
           shouldReuse(
                session: session,
                baseSelectionText: EditorMultiCursorMatcher.selectionText(
                    for: session.baseSelection,
                    in: text
                ),
                currentSelectionText: currentSelectionText
           ) {
            return EditorMultiCursorResolvedContext(
                context: EditorMultiCursorSearchContext(
                    baseSelection: session.baseSelection,
                    query: session.query
                ),
                shouldStartSession: false
            )
        }

        guard let context = EditorMultiCursorMatcher.searchContext(
            from: normalizedRange,
            in: text
        ) else {
            return nil
        }

        return EditorMultiCursorResolvedContext(
            context: context,
            shouldStartSession: true
        )
    }

    static func startedSession(
        query: String,
        baseSelection: MultiCursorSelection
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchSession(
            query: query,
            baseSelection: baseSelection,
            history: [baseSelection]
        )
    }

    static func shouldReuse(
        session: EditorMultiCursorSearchSession,
        baseSelectionText: String?,
        currentSelectionText: String?
    ) -> Bool {
        baseSelectionText == session.query && currentSelectionText == session.query
    }

    static func nextSelection(
        in matches: [MultiCursorSelection],
        currentState: MultiCursorState,
        session: EditorMultiCursorSearchSession
    ) -> MultiCursorSelection? {
        let selectedSet = Set(currentState.all)
        let anchorIndex = matches.firstIndex(of: session.baseSelection)
            ?? matches.firstIndex(of: currentState.primary)
            ?? 0

        guard !matches.isEmpty else { return nil }

        for step in 1...matches.count {
            let candidate = matches[(anchorIndex + step) % matches.count]
            if !selectedSet.contains(candidate) {
                return candidate
            }
        }

        return nil
    }

    static func appending(
        _ selection: MultiCursorSelection,
        to session: EditorMultiCursorSearchSession
    ) -> EditorMultiCursorSearchSession {
        var updated = session
        updated.history.append(selection)
        return updated
    }

    static func allOccurrencesSession(
        query: String,
        baseSelection: MultiCursorSelection,
        matches: [MultiCursorSelection]
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchSession(
            query: query,
            baseSelection: baseSelection,
            history: matches
        )
    }

    static func removingLast(
        from session: EditorMultiCursorSearchSession
    ) -> EditorMultiCursorSearchSession? {
        guard session.history.count > 1 else { return nil }
        var updated = session
        updated.history.removeLast()
        return updated
    }

    static func session(
        for context: EditorMultiCursorSearchContext,
        matches: [MultiCursorSelection]? = nil
    ) -> EditorMultiCursorSearchSession {
        if let matches {
            return allOccurrencesSession(
                query: context.query,
                baseSelection: context.baseSelection,
                matches: matches
            )
        }
        return startedSession(
            query: context.query,
            baseSelection: context.baseSelection
        )
    }

    static func collapsedSession(
        from session: EditorMultiCursorSearchSession?,
        singleSelection: MultiCursorSelection,
        in text: NSString
    ) -> EditorMultiCursorSearchSession? {
        guard let session,
              session.baseSelection == singleSelection,
              EditorMultiCursorMatcher.selectionText(for: singleSelection, in: text) == session.query else {
            return nil
        }

        var updated = session
        updated.history = [singleSelection]
        return updated
    }
}
