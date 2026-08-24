import Foundation

/// A character card within a story.
public struct Character: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let storyID: UUID
    public var name: String
    public var role: String
    public var personality: String
    public var notes: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        storyID: UUID,
        name: String,
        role: String = "",
        personality: String = "",
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.storyID = storyID
        self.name = name
        self.role = role
        self.personality = personality
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
