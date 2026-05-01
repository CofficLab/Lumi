import Foundation

enum EditorFindReplaceTransactionBuilder {
    static func replaceCurrent(
        state: EditorFindReplaceState,
        matches: [EditorFindMatch]
    ) -> EditorTransaction? {
        guard let selectedIndex = state.selectedMatchIndex,
              matches.indices.contains(selectedIndex) else {
            return nil
        }

        let match = matches[selectedIndex]
        let replacementText = replacementText(for: match, state: state)
        let replacementLength = (replacementText as NSString).length

        return EditorTransaction(
            replacements: [
                .init(range: match.range, text: replacementText)
            ],
            updatedSelections: [
                .init(range: EditorRange(location: match.range.location, length: replacementLength))
            ]
        )
    }

    static func replaceAll(
        state: EditorFindReplaceState,
        matches: [EditorFindMatch]
    ) -> EditorTransaction? {
        guard !matches.isEmpty else { return nil }

        return EditorTransaction(
            replacements: matches.map { match in
                .init(range: match.range, text: replacementText(for: match, state: state))
            },
            updatedSelections: nil
        )
    }

    static func previewReplacementText(
        for match: EditorFindMatch,
        state: EditorFindReplaceState
    ) -> String {
        replacementText(for: match, state: state)
    }

    private static func replacementText(
        for match: EditorFindMatch,
        state: EditorFindReplaceState
    ) -> String {
        guard state.options.preservesCase else { return state.replaceText }
        return preservedCaseReplacement(state.replaceText, matchedText: match.matchedText)
    }

    private static func preservedCaseReplacement(
        _ replacement: String,
        matchedText: String
    ) -> String {
        guard !replacement.isEmpty, !matchedText.isEmpty else { return replacement }

        if matchedText == matchedText.uppercased() {
            return replacement.uppercased()
        }

        if matchedText == matchedText.lowercased() {
            return replacement.lowercased()
        }

        if matchedText.prefix(1) == matchedText.prefix(1).uppercased(),
           String(matchedText.dropFirst()) == String(matchedText.dropFirst()).lowercased() {
            return replacement.prefix(1).uppercased() + replacement.dropFirst().lowercased()
        }

        return replacement
    }
}
