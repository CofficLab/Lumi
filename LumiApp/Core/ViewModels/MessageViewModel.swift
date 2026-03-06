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
        messages[index] = message
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
