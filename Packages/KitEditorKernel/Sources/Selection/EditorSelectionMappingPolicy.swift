import Foundation

@MainActor
public enum EditorSelectionMappingPolicy {
    public static func canonicalSelectionSet(
        from viewRanges: [NSRange]
    ) -> EditorSelectionSet? {
        let validRanges = viewRanges
            .filter { $0.location != NSNotFound && $0.location >= 0 }

        guard !validRanges.isEmpty else { return nil }

        let mapped = validRanges
            .sorted { $0.location < $1.location }
            .map { EditorSelection(range: EditorRange(location: $0.location, length: $0.length)) }

        return EditorSelectionSet(selections: mapped)
    }

    public static func shouldAcceptCanonicalUpdate(
        viewSelections: EditorSelectionSet,
        currentState: EditorSelectionSet
    ) -> Bool {
        if !currentState.isMultiCursor && !viewSelections.isMultiCursor {
            return true
        }

        if currentState.isMultiCursor && viewSelections.count < currentState.count {
            return false
        }

        return true
    }

    public static func targetViewRanges(
        for selectionSet: EditorSelectionSet
    ) -> [NSRange] {
        selectionSet.selections.map(\.range.nsRange)
    }

    public static func rangesAreEqual(
        _ lhs: [NSRange],
        _ rhs: [NSRange]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { $0 == $1 }
    }
}
