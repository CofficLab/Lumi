import Foundation
import MagicKit
import SwiftData
import SwiftUI

/// 会话管理 ViewModel
@MainActor
final class ConversationVM: ObservableObject, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "💬"

    /// 是否启用详细日志
    nonisolated static let verbose = false

    // MARK: - 服务依赖

    /// 聊天历史服务
    ///
    /// 负责会话和消息的持久化操作。
    private let chatHistoryService: ChatHistoryService

    // MARK: - 会话状态

    /// 选中的会话 ID
    ///
    /// 此类只维护此 ID，不持有 Conversation 对象引用。
    /// 需要会话数据的视图应使用 @Query 根据 ID 自行查询：
    ///
    /// ```swift
    /// @Query(filter: #Predicate<Conversation> { $0.id == viewModel.selectedConversationId })
    /// var selectedConversation: [Conversation]
    /// ```
    @Published public fileprivate(set) var selectedConversationId: UUID?

    // MARK: - 初始化

    /// 使用依赖服务初始化
    ///
    /// - Parameters:
    ///   - chatHistoryService: 聊天历史服务
    init(
        chatHistoryService: ChatHistoryService
    ) {
        self.chatHistoryService = chatHistoryService

        // 启动时如果没有任何插件恢复会话选择，这里会自动选择一个有效会话
        selfHealSelectedConversationIfNeeded()
    }

    // MARK: - 会话管理

    /// 保存消息到当前对话
    ///
    /// - Parameter message: 要保存的消息
    func saveMessage(_ message: ChatMessage) async {
        guard let conversationId = selectedConversationId else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 当前没有选中会话，跳过保存")
            }
            return
        }
        await saveMessage(message, to: conversationId)
    }

    /// 保存消息到指定对话
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversationId: 目标对话 ID
    func saveMessage(_ message: ChatMessage, to conversationId: UUID) async {
        let saved = await chatHistoryService.saveMessageAsync(message, toConversationId: conversationId)
        if Self.verbose, saved != nil {
            AppLogger.core.info("\(Self.t)💾 [\(conversationId)] 消息已保存：\(message.content.max(50))")
        }
    }

    /// 删除指定对话
    /// - Parameter conversation: 要删除的对话
    /// - Note: 调用方（如 AgentRuntime）需要负责清理相关的消息发送队列
    func deleteConversation(_ conversation: Conversation) {
        AppLogger.core.info("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")

        // 如果删除的是选中的对话，清理状态
        if selectedConversationId == conversation.id {
            selectedConversationId = nil
        }

        chatHistoryService.deleteConversation(conversation)

        AppLogger.core.info("\(Self.t)✅ 对话已删除：\(conversation.title)")
    }

    /// 更新对话标题
    ///
    /// - Parameters:
    ///   - conversation: 要更新的对话
    ///   - newTitle: 新标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        chatHistoryService.updateConversationTitle(conversation, newTitle: newTitle)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
        }
    }

    /// 基于第一条消息生成会话标题
    ///
    /// 使用 LLM 根据用户的第一条消息自动生成会话标题。
    ///
    /// - Parameters:
    ///   - userMessage: 用户的第一条消息
    ///   - config: LLM 配置
    /// - Returns: 生成的标题
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await chatHistoryService.generateConversationTitle(from: userMessage, config: config)
    }

    // MARK: - 会话选择

    /// 设置当前选中的会话
    /// - Parameter id: 会话 ID，传入 nil 表示清除选择
    func setSelectedConversation(_ id: UUID?) {
        // 避免重复设置相同的 ID
        guard selectedConversationId != id else {
            if let existingId = id, Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ 会话已选中，跳过重复设置: \(existingId)")
            }
            return
        }

        selectedConversationId = id
    }

    /// 启动时自愈当前选中会话
    ///
    /// - 如果 `selectedConversationId` 指向的会话在数据库中已不存在：
    ///   - 若还有其他会话：自动切换到最新的一个
    ///   - 若一个会话都没有：清空选中状态
    /// - 如果本地没有记录任何选中 ID，但数据库中存在会话：
    ///   - 自动选中最新的一个，避免用户打开时看到完全空白状态
    private func selfHealSelectedConversationIfNeeded() {
        // 情况 1：有记录的 ID，但数据库中不存在对应会话
        if let id = selectedConversationId,
           fetchConversation(id: id) == nil {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)⚠️ [\(id)] 恢复的会话在数据库中不存在，尝试自动修正")
            }

            let all = fetchAllConversations()
            if let first = all.first {
                // 切换到最新的一个有效会话
                selectedConversationId = first.id
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)✅ 已自动切换到最新对话：\(first.id)")
                }
            } else {
                // 没有任何会话，清空状态
                selectedConversationId = nil
            }
            return
        }

        // 情况 2：没有记录选中 ID，但数据库中已经有对话
        if selectedConversationId == nil {
            let all = fetchAllConversations()
            if let first = all.first {
                selectedConversationId = first.id
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)✅ 未记录选中会话，已自动选中最新对话：\(first.id)")
                }
            }
        }
    }

    // MARK: - 获取会话列表

    /// 获取所有对话
    ///
    /// - Returns: 按时间倒序排列的会话列表
    func fetchAllConversations() -> [Conversation] {
        chatHistoryService.fetchAllConversations()
    }

    /// 分页获取对话
    /// - Parameters:
    ///   - limit: 每页数量
    ///   - offset: 偏移量
    /// - Returns: 当前页数据
    func fetchConversationsPage(limit: Int, offset: Int) -> [Conversation] {
        chatHistoryService.fetchConversationsPage(limit: limit, offset: offset)
    }

    /// 根据 ID 获取会话
    /// - Parameter id: 会话 ID
    /// - Returns: 会话，不存在时返回 nil
    func fetchConversation(id: UUID) -> Conversation? {
        chatHistoryService.fetchConversation(id: id)
    }
}
