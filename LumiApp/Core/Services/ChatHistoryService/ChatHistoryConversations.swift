import Foundation
import SwiftData

// MARK: - 对话操作扩展

extension ChatHistoryService {

    // MARK: - 创建对话

    /// 创建新对话
    func createConversation(projectId: String? = nil, title: String = "新对话") -> Conversation {
        let conversation = Conversation(
            projectId: projectId,
            title: title,
            createdAt: Date(),
            updatedAt: Date()
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
        // 如果消息很短（≤15 字符），直接用作标题
        let trimmedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.count <= 15 {
            return String(trimmedMessage.prefix(20))
        }

        // API Key 无效时直接降级，避免触发无意义的 500 错误
        guard !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return String(trimmedMessage.prefix(20))
        }

        // 否则使用 LLM 生成简洁标题
        let titlePrompt = """
        请为以下用户消息生成一个简洁的对话标题（最多 10 个中文字符或 15 个英文字符）：

        用户消息：\(trimmedMessage)

        要求：
        - 标题要准确反映用户的核心需求
        - 简洁明了
        - 不要使用标点符号
        - 直接返回标题，不要解释
        """

        do {
            let titleConfig = LLMConfig(
                apiKey: config.apiKey,
                model: config.model,
                providerId: config.providerId
            )

            // 使用简单的消息结构请求标题
            let titleMessages: [ChatMessage] = [
                ChatMessage(role: .user, conversationId: UUID(), content: titlePrompt),
            ]

            let response = try await llmService.sendMessage(
                messages: titleMessages,
                config: titleConfig,
                tools: []
            )

            // 配置类问题会返回 `role: .system` 的占位消息，不能用作标题
            guard response.role == .assistant else {
                return String(trimmedMessage.prefix(20))
            }

            let generatedTitle = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // 确保标题长度合适
            if generatedTitle.count <= 20 {
                return generatedTitle
            } else {
                return String(generatedTitle.prefix(20))
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 生成标题失败：\(error.localizedDescription)")
            // 降级：使用消息的前 20 个字符作为标题
            return String(trimmedMessage.prefix(20))
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
