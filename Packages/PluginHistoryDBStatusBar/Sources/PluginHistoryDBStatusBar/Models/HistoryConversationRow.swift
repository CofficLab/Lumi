import Foundation

public struct HistoryConversationRow: Identifiable {
    public let id: UUID
    public let title: String
    public let projectId: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    public let providerId: String?
    public let model: String?
    public let chatMode: String?
}
