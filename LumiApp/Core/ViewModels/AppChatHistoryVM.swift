import Foundation
import LLMKit

/// 聊天历史 ViewModel
///
/// 管理聊天历史和对话的服务访问，提供统一的操作接口。
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var chatHistoryVM: AppChatHistoryVM` 访问。
@MainActor
final class AppChatHistoryVM: ObservableObject {
    // MARK: - Properties

    /// 聊天历史服务（消息操作）
    let chatHistoryService: ChatHistoryService

    /// 对话服务（对话表 CRUD）
    let conversationService: ConversationService

    // MARK: - Initialization

    init(chatHistoryService: ChatHistoryService, conversationService: ConversationService) {
        self.chatHistoryService = chatHistoryService
        self.conversationService = conversationService
    }

    // MARK: - 消息操作（委托给 ChatHistoryService）

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

    /// 获取消息总数
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await chatHistoryService.getMessageCount(forConversationId: conversationId)
    }

    /// 获取对话时间线状态栏所需的轻量统计信息。
    func getConversationTimelineSummary(
        forConversationId conversationId: UUID
    ) -> ChatHistoryService.ConversationTimelineSummary {
        chatHistoryService.getConversationTimelineSummary(forConversationId: conversationId)
    }

    /// 异步加载对话消息
    func loadMessagesAsync(forConversationId conversationId: UUID) -> [ChatMessage]? {
        chatHistoryService.loadMessages(forConversationId: conversationId)
    }

    /// 异步保存消息
    @discardableResult
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: UUID) -> ChatMessage? {
        chatHistoryService.saveMessage(message, toConversationId: conversationId)
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

    // MARK: - 对话操作（委托给 ConversationService）

    /// 创建新对话
    @discardableResult
    func createConversation(
        projectId: String? = nil,
        title: String = "新对话",
        chatMode: String? = nil
    ) -> Conversation {
        conversationService.createConversation(
            projectId: projectId,
            title: title,
            chatMode: chatMode
        )
    }

    /// 获取所有对话（按创建时间倒序）
    func fetchAllConversations() -> [Conversation] {
        conversationService.fetchAllConversations()
    }

    /// 分页获取对话
    func fetchConversationsPage(
        limit: Int,
        offset: Int,
        projectId: String? = nil
    ) -> [Conversation] {
        conversationService.fetchConversationsPage(
            limit: limit,
            offset: offset,
            projectId: projectId
        )
    }

    /// 获取指定项目最近更新的一个对话
    func fetchLatestConversation(projectId: String) -> Conversation? {
        conversationService.fetchLatestConversation(projectId: projectId)
    }

    /// 根据 ID 获取对话
    func fetchConversation(id: UUID) -> Conversation? {
        conversationService.fetchConversation(id: id)
    }

    /// 更新对话标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        conversationService.updateConversationTitle(conversation, newTitle: newTitle)
    }

    /// 基于用户消息自动生成会话标题
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await conversationService.generateConversationTitle(from: userMessage, config: config)
    }

    /// 更新对话的供应商/模型偏好
    func updateModelPreference(_ conversation: Conversation, providerId: String?, model: String?) {
        conversationService.updateModelPreference(conversation, providerId: providerId, model: model)
    }

    /// 更新对话的聊天模式偏好
    func updateChatMode(_ conversation: Conversation, chatMode: String?) {
        conversationService.updateChatMode(conversation, chatMode: chatMode)
    }

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        conversationService.deleteConversation(conversation)
    }
}
