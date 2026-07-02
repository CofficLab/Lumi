import Foundation

public struct HistoryMessageRow: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let conversationId: UUID
    public let conversationTitle: String
    public let role: String
    public let model: String
    public let tokens: Int
    public let timestamp: Date
    public let contentPreview: String
    public let thinkingContentPreview: String?
    public let hasThinking: Bool
    public let thinkingDuration: Double?

    public init(
        id: UUID,
        conversationId: UUID,
        conversationTitle: String,
        role: String,
        model: String,
        tokens: Int,
        timestamp: Date,
        contentPreview: String,
        thinkingContentPreview: String? = nil,
        hasThinking: Bool = false,
        thinkingDuration: Double? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.conversationTitle = conversationTitle
        self.role = role
        self.model = model
        self.tokens = tokens
        self.timestamp = timestamp
        self.contentPreview = contentPreview
        self.thinkingContentPreview = thinkingContentPreview
        self.hasThinking = hasThinking
        self.thinkingDuration = thinkingDuration
    }
}

public struct HistoryConversationRow: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let projectId: String
    public let createdAt: Date
    public let updatedAt: Date
    public let messageCount: Int
    public let providerId: String?
    public let model: String?
    public let chatMode: String?

    public init(
        id: UUID,
        title: String,
        projectId: String,
        createdAt: Date,
        updatedAt: Date,
        messageCount: Int,
        providerId: String?,
        model: String?,
        chatMode: String?
    ) {
        self.id = id
        self.title = title
        self.projectId = projectId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messageCount = messageCount
        self.providerId = providerId
        self.model = model
        self.chatMode = chatMode
    }
}

@MainActor
public protocol HistoryQueryService: AnyObject {
    func fetchMessageCount() async -> Int
    func fetchMessagePage(limit: Int, offset: Int) async -> [HistoryMessageRow]
    func fetchConversationCount() async -> Int
    func fetchConversationPage(limit: Int, offset: Int) async -> [HistoryConversationRow]
}
