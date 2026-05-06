import Foundation

public struct EditorFindMatch: Equatable, Sendable {
    public let range: EditorRange
    public let matchedText: String

    public init(range: EditorRange, matchedText: String) {
        self.range = range
        self.matchedText = matchedText
    }
}

public struct EditorFindMatchesResult: Equatable, Sendable {
    public let matches: [EditorFindMatch]
    public let selectedMatchIndex: Int?
    public let selectedMatchRange: EditorRange?

    public init(matches: [EditorFindMatch], selectedMatchIndex: Int?, selectedMatchRange: EditorRange?) {
        self.matches = matches
        self.selectedMatchIndex = selectedMatchIndex
        self.selectedMatchRange = selectedMatchRange
    }
}
