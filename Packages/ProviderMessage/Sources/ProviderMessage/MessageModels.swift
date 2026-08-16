import Foundation

public enum MessageRole: String, Codable, Sendable, CaseIterable {
    case system
    case user
    case assistant
    case tool
    case error
    case status
}

public struct Message: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: MessageRole
    public var content: String
    public let createdAt: Date
    public var turnID: UUID?
    public var metadata: [String: String]
    public var isError: Bool

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        turnID: UUID? = nil,
        metadata: [String: String] = [:],
        isError: Bool = false
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.turnID = turnID
        self.metadata = metadata
        self.isError = isError
    }
}
