import Foundation

public struct HistoryMessageRow: Identifiable {
    public let id: UUID
    public let conversationId: UUID
    public let conversationTitle: String
    public let role: String
    public let model: String
    public let tokens: Int
    public let timestamp: Date
    public let contentPreview: String
}
