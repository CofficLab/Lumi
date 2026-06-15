import Foundation

public struct DocumentHighlightSnapshot: Sendable, Equatable {
    public let key: DocumentHighlightKey
    public let highlightRevision: Int
    public let runs: [HighlightRange]

    public init(key: DocumentHighlightKey, highlightRevision: Int, runs: [HighlightRange]) {
        self.key = key
        self.highlightRevision = highlightRevision
        self.runs = runs
    }
}
