import Foundation
import SwiftData
import LLMKit

// MARK: - 对话操作扩展

extension ChatHistoryService {

    // MARK: - 创建对话

    /// 创建新对话
    func createConversation(projectId: String? = nil, title: String = "新对话", chatMode: String? = nil) -> Conversation {
        let conversation = Conversation(
            projectId: projectId,
            title: title,
            createdAt: Date(),
            updatedAt: Date(),
            chatMode: chatMode
        )

        saveConversation(conversation)
        notifyConversationChanged(type: .created, conversationId: conversation.id)
        NotificationCenter.postConversationCreated(conversationId: conversation.id)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✨ 创建新对话：\(title)")
        }

        return conversation
    }

    // MARK: - 更新对话标题

    /// 更新对话标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        conversation.title = newTitle
        conversation.updatedAt = Date()

        saveConversation(conversation)
        notifyConversationChanged(type: .updated, conversationId: conversation.id)
        NotificationCenter.postConversationUpdated(conversationId: conversation.id)

        if Self.verbose {
            AppLogger.core.info("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
        }
    }

    // MARK: - 生成会话标题

    /// 基于用户消息生成会话标题
    /// - Parameters:
    ///   - userMessage: 用户的第一条消息
    ///   - config: LLM 配置
    /// - Returns: 生成的标题（最多 20 个字符）
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await ConversationTitleGenerator().generate(userMessage: userMessage, config: config) { [llmService] messages, config in
            try await llmService.sendMessage(messages: messages, config: config, tools: [])
        }
    }

    // MARK: - 更新对话模型偏好

    /// 更新对话的供应商/模型偏好
    /// - Parameters:
    ///   - conversation: 目标对话
    ///   - providerId: 供应商 ID，nil 表示清除对话级偏好（回退到项目偏好）
    ///   - model: 模型名称，nil 表示清除对话级偏好（回退到项目偏好）
    func updateModelPreference(_ conversation: Conversation, providerId: String?, model: String?) {
        conversation.providerId = providerId
        conversation.model = model
        conversation.updatedAt = Date()

        saveConversation(conversation)

        if Self.verbose {
            if let providerId, let model {
                AppLogger.core.info("\(Self.t)🎯 已保存对话 '\(conversation.title)' 的模型偏好：\(providerId) - \(model)")
            } else {
                AppLogger.core.info("\(Self.t)🎯 已清除对话 '\(conversation.title)' 的模型偏好")
            }
        }
    }

    // MARK: - 更新对话聊天模式

    /// 更新对话的聊天模式偏好
    /// - Parameters:
    ///   - conversation: 目标对话
    ///   - chatMode: 聊天模式 rawValue，nil 表示清除对话级偏好（回退到全局偏好）
    func updateChatMode(_ conversation: Conversation, chatMode: String?) {
        conversation.chatMode = chatMode
        conversation.updatedAt = Date()

        saveConversation(conversation)

        if Self.verbose {
            if let chatMode {
                AppLogger.core.info("\(Self.t)🔄 已保存对话 '\(conversation.title)' 的聊天模式：\(chatMode)")
            } else {
                AppLogger.core.info("\(Self.t)🔄 已清除对话 '\(conversation.title)' 的聊天模式")
            }
        }
    }

    // MARK: - 加载对话

    /// 获取所有对话
    func fetchAllConversations() -> [Conversation] {
        let context = self.getContext()
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let conversations = try context.fetch(descriptor)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📄 获取到 \(conversations.count) 个对话")
            }
            return conversations
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 分页获取对话
    /// - Parameters:
    ///   - limit: 每页数量
    ///   - offset: 偏移量
    ///   - projectId: 可选项目 ID；为 nil 时拉取全部对话
    /// - Returns: 当前页对话数据
    func fetchConversationsPage(limit: Int, offset: Int, projectId: String? = nil) -> [Conversation] {
        let context = self.getContext()

        guard limit > 0, offset >= 0 else { return [] }

        var descriptor: FetchDescriptor<Conversation>
        if let projectId {
            descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.projectId == projectId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }

        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset

        do {
            return try context.fetch(descriptor)
        } catch {
            AppLogger.core.error("\(Self.t)❌ 分页获取对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 获取指定项目最近更新的一个对话
    /// - Parameter projectId: 项目路径
    /// - Returns: 该项目最近使用的对话，不存在时返回 nil
    func fetchLatestConversation(projectId: String) -> Conversation? {
        let context = self.getContext()
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        do {
            return try context.fetch(descriptor).first
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取项目最新对话失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 根据 ID 获取对话
    func fetchConversation(id: UUID) -> Conversation? {
        let context = self.getContext()
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            let conversations = try context.fetch(descriptor)
            return conversations.first
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return nil
        }
    }
}
