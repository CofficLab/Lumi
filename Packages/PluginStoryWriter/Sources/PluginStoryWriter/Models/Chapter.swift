import Foundation

/// A chapter within a story.
public struct Chapter: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let storyID: UUID
    public var title: String
    public var content: String
    public var status: ChapterStatus
    public var targetWordCount: Int
    public let createdAt: Date
    public var updatedAt: Date

    public var wordCount: Int {
        // Rough Chinese-friendly word count: count non-whitespace characters.
        content.filter { !$0.isWhitespace }.count
    }

    public init(
        id: UUID = UUID(),
        storyID: UUID,
        title: String,
        content: String = "",
        status: ChapterStatus = .draft,
        targetWordCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.storyID = storyID
        self.title = title
        self.content = content
        self.status = status
        self.targetWordCount = targetWordCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
