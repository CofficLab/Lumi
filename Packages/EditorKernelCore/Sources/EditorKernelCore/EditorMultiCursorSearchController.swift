import Foundation

public struct EditorMultiCursorSearchContext: Equatable, Sendable {
    public let baseSelection: MultiCursorSelection
    public let query: String

    public init(baseSelection: MultiCursorSelection, query: String) {
        self.baseSelection = baseSelection
        self.query = query
    }
}

public struct EditorMultiCursorSearchSession: Equatable, Sendable {
    public let query: String
    public let baseSelection: MultiCursorSelection
    public var history: [MultiCursorSelection]

    public init(query: String, baseSelection: MultiCursorSelection, history: [MultiCursorSelection]) {
        self.query = query
        self.baseSelection = baseSelection
        self.history = history
    }
}

public struct EditorMultiCursorResolvedContext: Equatable, Sendable {
    public let context: EditorMultiCursorSearchContext
    public let shouldStartSession: Bool

    public init(context: EditorMultiCursorSearchContext, shouldStartSession: Bool) {
        self.context = context
        self.shouldStartSession = shouldStartSession
    }
}

public enum EditorMultiCursorSearchController {
    public static func resolvedContext(
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

    public static func startedSession(
        query: String,
        baseSelection: MultiCursorSelection
    ) -> EditorMultiCursorSearchSession {
        EditorMultiCursorSearchSession(
            query: query,
            baseSelection: baseSelection,
            history: [baseSelection]
        )
    }

    public static func shouldReuse(
        session: EditorMultiCursorSearchSession,
        baseSelectionText: String?,
        currentSelectionText: String?
    ) -> Bool {
        baseSelectionText == session.query && currentSelectionText == session.query
    }

    public static func nextSelection(
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

    public static func appending(
        _ selection: MultiCursorSelection,
        to session: EditorMultiCursorSearchSession
    ) -> EditorMultiCursorSearchSession {
        var updated = session
        updated.history.append(selection)
        return updated
    }

    public static func allOccurrencesSession(
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

    public static func removingLast(
        from session: EditorMultiCursorSearchSession
    ) -> EditorMultiCursorSearchSession? {
        guard session.history.count > 1 else { return nil }
        var updated = session
        updated.history.removeLast()
        return updated
    }

    public static func session(
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

    public static func collapsedSession(
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
