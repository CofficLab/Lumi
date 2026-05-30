import Foundation

/// 历史对话行数据（轻量 DTO）
///
/// 用于插件展示对话历史列表，不暴露内核 SwiftData Entity 细节。
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
