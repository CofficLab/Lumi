import Foundation

struct EditorFindMatch: Equatable, Sendable {
    let range: EditorRange
    let matchedText: String
}

struct EditorFindMatchesResult: Equatable, Sendable {
    let matches: [EditorFindMatch]
    let selectedMatchIndex: Int?
    let selectedMatchRange: EditorRange?
}
