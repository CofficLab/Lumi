import Foundation

@MainActor
final class EditorFindController {
    func stateForOpeningPanel(_ state: EditorFindReplaceState) -> EditorFindReplaceState {
        var updated = state
        updated.isFindPanelVisible = true
        return updated
    }

    func stateForClosingPanel(_ state: EditorFindReplaceState) -> EditorFindReplaceState {
        var updated = state
        updated.isFindPanelVisible = false
        return updated
    }

    func stateForUpdatingFindQuery(_ state: EditorFindReplaceState, text: String) -> EditorFindReplaceState {
        var updated = state
        updated.findText = text
        updated.isFindPanelVisible = true
        return updated
    }

    func stateForUpdatingReplaceQuery(_ state: EditorFindReplaceState, text: String) -> EditorFindReplaceState {
        var updated = state
        updated.replaceText = text
        updated.isFindPanelVisible = true
        return updated
    }

    func stateForUpdatingOptions(
        _ state: EditorFindReplaceState,
        transform: (inout EditorFindReplaceOptions) -> Void
    ) -> EditorFindReplaceState {
        var updated = state
        transform(&updated.options)
        return updated
    }

    func matchesResult(
        state: EditorFindReplaceState,
        text: String,
        selections: [EditorSelection]
    ) -> EditorFindMatchesResult {
        EditorFindReplaceController.matches(
            in: text,
            state: state,
            selections: selections,
            primarySelection: selections.first
        )
    }

    func nextMatchIndex(
        matches: [EditorFindMatch],
        selectedMatchIndex: Int?
    ) -> Int? {
        EditorFindReplaceController.nextMatchIndex(
            in: matches,
            selectedMatchIndex: selectedMatchIndex
        )
    }

    func previousMatchIndex(
        matches: [EditorFindMatch],
        selectedMatchIndex: Int?
    ) -> Int? {
        EditorFindReplaceController.previousMatchIndex(
            in: matches,
            selectedMatchIndex: selectedMatchIndex
        )
    }

    func replaceCurrentTransaction(
        state: EditorFindReplaceState,
        matches: [EditorFindMatch]
    ) -> EditorTransaction? {
        EditorFindReplaceTransactionBuilder.replaceCurrent(
            state: state,
            matches: matches
        )
    }

    func replaceAllTransaction(
        state: EditorFindReplaceState,
        matches: [EditorFindMatch]
    ) -> EditorTransaction? {
        EditorFindReplaceTransactionBuilder.replaceAll(
            state: state,
            matches: matches
        )
    }

    func applyMatchesResult(
        _ result: EditorFindMatchesResult,
        to state: inout EditorFindReplaceState
    ) {
        state.resultCount = result.matches.count
        state.selectedMatchIndex = result.selectedMatchIndex
        state.selectedMatchRange = result.selectedMatchRange
    }

    func applySelectedMatch(
        index: Int,
        match: EditorFindMatch,
        to state: inout EditorFindReplaceState
    ) {
        state.selectedMatchIndex = index
        state.selectedMatchRange = match.range
    }
}
