import Foundation
import MagicKit
import SwiftUI
import OSLog
import SwiftData

/// 消息管理 ViewModel
/// 负责处理所有消息相关的业务逻辑，包括加载、保存、追加、更新、删除消息等
@MainActor
final class MessageViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 聊天历史服务
    private let chatHistoryService: ChatHistoryService

    // MARK: - 消息状态

    /// 当前会话的消息列表
    @Published public fileprivate(set) var messages: [ChatMessage] = []

    /// 标记是否已生成标题
    @Published public fileprivate(set) var hasGeneratedTitle: Bool = false

    // MARK: - 分页状态

    /// 每页消息数量
    public static let pageSize: Int = 80

    /// 是否还有更多历史消息可加载
    @Published public fileprivate(set) var hasMoreMessages: Bool = false

    /// 是否正在加载更多消息
    @Published public fileprivate(set) var isLoadingMore: Bool = false

    /// 最早加载的消息时间戳（用于分页游标）
    private var oldestLoadedTimestamp: Date?

    /// 当前会话的消息总数
    @Published public fileprivate(set) var totalMessageCount: Int = 0

    // MARK: - 内部方法（仅供外部使用）

    /// 设置消息列表（内部使用）
    func setMessagesInternal(_ newMessages: [ChatMessage]) {
        messages = newMessages
    }

    /// 追加消息（内部使用）
    func appendMessageInternal(_ message: ChatMessage) {
        messages.append(message)
    }

    /// 插入消息（内部使用）
    func insertMessageInternal(_ message: ChatMessage, at index: Int) {
        messages.insert(message, at: index)
    }

    /// 更新消息（内部使用）
    func updateMessageInternal(_ message: ChatMessage, at index: Int) {
        // 创建新数组以触发 SwiftUI 更新
        var updatedMessages = messages
        updatedMessages[index] = message
        messages = updatedMessages
    }

    /// 设置标题生成标记（内部使用）
    func setHasGeneratedTitleInternal(_ value: Bool) {
        hasGeneratedTitle = value
    }

    // MARK: - 初始化

    /// 使用聊天历史服务初始化
    init(chatHistoryService: ChatHistoryService) {
        self.chatHistoryService = chatHistoryService
    }

    // MARK: - 消息管理

    /// 加载指定会话的消息
    /// - Parameter conversation: 会话
    func loadMessages(for conversation: Conversation) -> [ChatMessage] {
        let loadedMessages = chatHistoryService.loadMessages(for: conversation)
        messages = loadedMessages

        if Self.verbose {
            os_log("\(Self.t)📥 [\(conversation.id)] 消息加载完成，共 \(loadedMessages.count) 条消息")
        }

        return loadedMessages
    }

    /// 按会话 ID 异步加载消息（后台 I/O）- 全量加载（兼容旧代码）
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 会话是否存在
    @discardableResult
    func loadMessages(conversationId: UUID) async -> Bool {
        guard let loadedMessages = await chatHistoryService.loadMessagesAsync(forConversationId: conversationId) else {
            return false
        }
        messages = loadedMessages
        return true
    }

    /// 分页加载消息（初始加载最近消息）
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 是否成功加载
    @discardableResult
    func loadMessagesPaginated(conversationId: UUID) async -> Bool {
        // 重置分页状态
        oldestLoadedTimestamp = nil
        hasMoreMessages = false
        isLoadingMore = false

        // 获取消息总数
        totalMessageCount = await chatHistoryService.getMessageCount(forConversationId: conversationId)

        // 加载第一页（最近的消息）
        let result = await chatHistoryService.loadMessagesPage(
            forConversationId: conversationId,
            limit: Self.pageSize,
            beforeTimestamp: nil
        )

        messages = result.messages
        hasMoreMessages = result.hasMore

        // 更新最早加载的时间戳
        if let firstMessage = messages.first {
            oldestLoadedTimestamp = firstMessage.timestamp
        }

        if Self.verbose {
            os_log("\(Self.t)📄 [\(conversationId)] 分页加载完成: \(self.messages.count)/\(self.totalMessageCount) 条, hasMore: \(self.hasMoreMessages)")
        }

        return !messages.isEmpty || totalMessageCount == 0
    }

    /// 加载更多历史消息（上滑时调用）
    /// - Parameter conversationId: 会话 ID
    /// - Returns: 新加载的消息数量
    @discardableResult
    func loadMoreMessages(conversationId: UUID) async -> Int {
        guard hasMoreMessages, !isLoadingMore else {
            return 0
        }

        isLoadingMore = true
        defer { isLoadingMore = false }

        // 使用最早加载消息的时间戳作为游标
        let beforeTimestamp = oldestLoadedTimestamp

        let result = await chatHistoryService.loadMessagesPage(
            forConversationId: conversationId,
            limit: Self.pageSize,
            beforeTimestamp: beforeTimestamp
        )

        // 新加载的消息插入到列表前面（更早的消息）
        let newMessages = result.messages
        messages.insert(contentsOf: newMessages, at: 0)
        hasMoreMessages = result.hasMore

        // 更新最早加载的时间戳
        if let firstMessage = newMessages.first {
            oldestLoadedTimestamp = firstMessage.timestamp
        }

        if Self.verbose {
            os_log("\(Self.t)📄 [\(conversationId)] 加载更多消息: +\(newMessages.count) 条, 总计: \(self.messages.count) 条")
        }

        return newMessages.count
    }

    /// 重置分页状态
    func resetPagination() {
        hasMoreMessages = false
        isLoadingMore = false
        oldestLoadedTimestamp = nil
        totalMessageCount = 0
    }

    /// 设置是否还有更多消息（内部使用）
    func setHasMoreMessagesInternal(_ value: Bool) {
        hasMoreMessages = value
    }

    /// 设置消息总数（内部使用）
    func setTotalMessageCountInternal(_ value: Int) {
        totalMessageCount = value
    }

    /// 保存消息到指定会话
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversation: 目标会话
    /// - Returns: 保存后的消息
    @discardableResult
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) -> ChatMessage? {
        let savedMessage = chatHistoryService.saveMessage(message, to: conversation)

        // 同时更新本地消息列表（避免重复添加）
        if let saved = savedMessage, !messages.contains(where: { $0.id == saved.id }) {
            appendMessageInternal(saved)

            if Self.verbose {
                os_log("\(Self.t)💾 [\(conversation.id)] 消息已保存：\(message.content.max(50))")
            }
        }

        return savedMessage
    }

    /// 批量保存消息到指定会话
    /// - Parameters:
    ///   - messages: 要保存的消息数组
    ///   - conversation: 目标会话
    func saveMessages(_ messages: [ChatMessage], to conversation: Conversation) {
        for message in messages {
            saveMessage(message, to: conversation)
        }
    }

    /// 追加消息到本地列表（不保存到数据库）
    /// - Parameter message: 要追加的消息
    func appendMessage(_ message: ChatMessage) {
        appendMessageInternal(message)

        if Self.verbose {
            os_log("\(Self.t)📝 消息已追加到本地列表")
        }
    }

    /// 插入消息到本地列表（不保存到数据库）
    /// - Parameters:
    ///   - message: 要插入的消息
    ///   - index: 插入位置
    func insertMessage(_ message: ChatMessage, at index: Int) {
        insertMessageInternal(message, at: index)

        if Self.verbose {
            os_log("\(Self.t)📝 消息已插入到本地列表位置 \(index)")
        }
    }

    /// 更新本地消息列表中的消息（不更新数据库）
    /// - Parameters:
    ///   - message: 新消息
    ///   - index: 更新位置
    func updateMessage(_ message: ChatMessage, at index: Int) {
        guard index >= 0, index < messages.count else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 更新消息失败：索引越界")
            }
            return
        }

        updateMessageInternal(message, at: index)

        if Self.verbose {
            os_log("\(Self.t)📝 消息已更新在本地列表位置 \(index)")
        }
    }

    /// 删除本地消息列表中的最后一条消息
    func removeLastMessage() {
        guard !messages.isEmpty else { return }
        messages.removeLast()

        if Self.verbose {
            os_log("\(Self.t)🗑️ 已删除最后一条消息")
        }
    }

    /// 清空消息列表
    func clearMessages() {
        messages.removeAll()
        hasGeneratedTitle = false

        if Self.verbose {
            os_log("\(Self.t)🗑️ 消息列表已清空")
        }
    }

    /// 获取最后一条用户消息
    func lastUserMessage() -> ChatMessage? {
        messages.last(where: { $0.role == .user })
    }

    /// 获取第一条用户消息
    func firstUserMessage() -> ChatMessage? {
        messages.first(where: { $0.role == .user })
    }

    /// 获取最后一条消息
    func lastMessage() -> ChatMessage? {
        messages.last
    }

    /// 获取非系统消息列表
    func nonSystemMessages() -> [ChatMessage] {
        messages.filter { $0.role != .system }
    }
}
