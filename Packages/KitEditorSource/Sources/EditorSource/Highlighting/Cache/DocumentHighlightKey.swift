import Foundation

public struct DocumentHighlightKey: Hashable, Sendable {
    public let standardizedFileURL: URL
    public let contentDigest: String
    public let languageId: String

    public init(fileURL: URL, content: String, languageId: String) {
        self.standardizedFileURL = fileURL.standardizedFileURL
        self.contentDigest = DocumentHighlightDigest.compute(for: content)
        self.languageId = languageId
    }

    public init(standardizedFileURL: URL, contentDigest: String, languageId: String) {
        self.standardizedFileURL = standardizedFileURL
        self.contentDigest = contentDigest
        self.languageId = languageId
    }

    public func matches(content: String) -> Bool {
        contentDigest == DocumentHighlightDigest.compute(for: content)
    }
}
