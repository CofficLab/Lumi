import Foundation

/// 历史消息行数据（轻量 DTO）
///
/// 用于插件展示消息历史列表，不暴露内核 SwiftData Entity 细节。
public struct HistoryMessageRow: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let conversationId: UUID
    public let conversationTitle: String
    public let role: String
    public let model: String
    public let tokens: Int
    public let timestamp: Date
    public let contentPreview: String

    public init(
        id: UUID,
        conversationId: UUID,
        conversationTitle: String,
        role: String,
        model: String,
        tokens: Int,
        timestamp: Date,
        contentPreview: String
    ) {
        self.id = id
        self.conversationId = conversationId
        self.conversationTitle = conversationTitle
        self.role = role
        self.model = model
        self.tokens = tokens
        self.timestamp = timestamp
        self.contentPreview = contentPreview
    }
}
