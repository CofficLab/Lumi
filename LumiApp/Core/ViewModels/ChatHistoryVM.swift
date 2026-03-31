import Foundation

/// 聊天历史 ViewModel
///
/// 管理聊天历史的服务访问，提供统一的聊天历史操作接口。
@MainActor
final class ChatHistoryVM: ObservableObject {
    // MARK: - Properties

    /// 聊天历史服务
    let chatHistoryService: ChatHistoryService

    // MARK: - Initialization

    init(chatHistoryService: ChatHistoryService) {
        self.chatHistoryService = chatHistoryService
    }

    // MARK: - Convenience Methods

    /// 获取模型详细性能统计
    func getModelDetailedStats() -> [String: ModelPerformanceStats] {
        chatHistoryService.getModelDetailedStats()
    }

    /// 获取模型延迟统计
    func getModelLatencyStats() -> [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] {
        chatHistoryService.getModelLatencyStats()
    }

    /// 分页加载消息
    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        await chatHistoryService.loadMessagesPage(
            forConversationId: conversationId,
            limit: limit,
            beforeTimestamp: beforeTimestamp
        )
    }

    /// 加载工具输出消息
    func loadToolOutputMessages(
        forConversationId conversationId: UUID,
        toolCallIDs: [String]
    ) async -> [ChatMessage] {
        await chatHistoryService.loadToolOutputMessages(
            forConversationId: conversationId,
            toolCallIDs: toolCallIDs
        )
    }

    /// 获取消息总数
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await chatHistoryService.getMessageCount(forConversationId: conversationId)
    }

    /// 异步加载对话消息
    func loadMessagesAsync(forConversationId conversationId: UUID) async -> [ChatMessage]? {
        await chatHistoryService.loadMessages(forConversationId: conversationId)
    }

    /// 异步保存消息
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: UUID) async -> ChatMessage? {
        await chatHistoryService.saveMessage(message, toConversationId: conversationId)
    }

    /// 异步更新消息
    func updateMessageAsync(_ message: ChatMessage, conversationId: UUID) async -> ChatMessage? {
        await chatHistoryService.updateMessageAsync(message, conversationId: conversationId)
    }

    /// 异步批量删除消息
    /// - Parameters:
    ///   - messageIds: 要删除的消息 ID 列表
    ///   - conversationId: 对话 ID（用于校验归属）
    /// - Returns: 实际删除的消息数量
    func deleteMessagesAsync(messageIds: [UUID], conversationId: UUID) async -> Int {
        await chatHistoryService.deleteMessagesAsync(messageIds: messageIds, conversationId: conversationId)
    }
}
