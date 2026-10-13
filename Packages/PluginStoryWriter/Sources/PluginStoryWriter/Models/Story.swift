import Foundation

/// A story (top-level container).
///
/// Stores metadata only; chapters and characters are referenced by ID and
/// loaded separately by `StoryStore`.
public struct Story: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var title: String
    public var synopsis: String
    public var chapterIDs: [UUID]
    public var characterIDs: [UUID]
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        synopsis: String = "",
        chapterIDs: [UUID] = [],
        characterIDs: [UUID] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.synopsis = synopsis
        self.chapterIDs = chapterIDs
        self.characterIDs = characterIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
