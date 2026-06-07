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

    /// 消息持久化服务
    let messageService: MessageService

    /// 聊天历史服务（LLM 上下文变换等）
    let chatHistoryService: ChatHistoryService

    /// 对话持久化服务
    let conversationService: ConversationService

    /// 性能统计服务
    let performanceService: PerformanceService

    // MARK: - Initialization

    init(
        messageService: MessageService,
        chatHistoryService: ChatHistoryService,
        conversationService: ConversationService,
        performanceService: PerformanceService
    ) {
        self.messageService = messageService
        self.chatHistoryService = chatHistoryService
        self.conversationService = conversationService
        self.performanceService = performanceService
    }

    // MARK: - 消息操作（委托给 MessageService）

    /// 分页加载消息
    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        await messageService.loadMessagesPage(
            forConversationId: conversationId,
            limit: limit,
            beforeTimestamp: beforeTimestamp
        )
    }

    /// 获取消息总数
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await messageService.getMessageCount(forConversationId: conversationId)
    }

    /// 获取对话时间线状态栏所需的轻量统计信息。
    func getConversationTimelineSummary(
        forConversationId conversationId: UUID
    ) -> MessageService.ConversationTimelineSummary {
        messageService.getConversationTimelineSummary(forConversationId: conversationId)
    }

    /// 异步加载对话消息
    func loadMessagesAsync(forConversationId conversationId: UUID) -> [ChatMessage]? {
        messageService.loadMessages(forConversationId: conversationId)
    }

    /// 异步保存消息
    @discardableResult
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: UUID) -> ChatMessage? {
        messageService.saveMessage(message, toConversationId: conversationId)
    }

    /// 异步更新消息
    func updateMessageAsync(_ message: ChatMessage, conversationId: UUID) async -> ChatMessage? {
        await messageService.updateMessageAsync(message, conversationId: conversationId)
    }

    /// 异步批量删除消息
    /// - Parameters:
    ///   - messageIds: 要删除的消息 ID 列表
    ///   - conversationId: 对话 ID（用于校验归属）
    /// - Returns: 实际删除的消息数量
    func deleteMessagesAsync(messageIds: [UUID], conversationId: UUID) async -> Int {
        await messageService.deleteMessagesAsync(messageIds: messageIds, conversationId: conversationId)
    }

    // MARK: - 对话操作（委托给 ConversationService）

    /// 创建新对话
    @discardableResult
    func createConversation(
        providerId: String,
        model: String,
        projectId: String? = nil,
        title: String = "",
        chatMode: String? = nil,
        languagePreference: String? = nil
    ) throws -> Conversation {
        try conversationService.createConversation(
            providerId: providerId,
            model: model,
            projectId: projectId,
            title: title,
            chatMode: chatMode,
            languagePreference: languagePreference
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


    /// 更新对话的供应商/模型偏好
    func updateModelPreference(_ conversation: Conversation, providerId: String?, model: String?) {
        conversationService.updateModelPreference(conversation, providerId: providerId, model: model)
    }

    /// 更新对话的聊天模式偏好
    func updateChatMode(_ conversation: Conversation, chatMode: String?) {
        conversationService.updateChatMode(conversation, chatMode: chatMode)
    }

    /// 更新对话的响应详细程度偏好
    func updateVerbosity(_ conversation: Conversation, verbosity: String?) {
        conversationService.updateVerbosity(conversation, verbosity: verbosity)
    }

    /// 更新对话的语言偏好
    func updateLanguagePreference(_ conversation: Conversation, languagePreference: String?) {
        conversationService.updateLanguagePreference(conversation, languagePreference: languagePreference)
    }

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        conversationService.deleteConversation(conversation)
    }

    // MARK: - 性能统计（委托给 PerformanceService）

    /// 获取每个供应商和模型的平均耗时
    func getModelLatencyStats() -> [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] {
        performanceService.getModelLatencyStats()
    }

    /// 获取每个供应商和模型的详细性能统计
    func getModelDetailedStats() -> [String: ModelPerformanceStats] {
        performanceService.getModelDetailedStats()
    }
}
