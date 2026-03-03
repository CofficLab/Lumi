import Foundation
import MagicKit
import OSLog
import SwiftData

/// 聊天历史服务 - 使用 SwiftData 存储对话
@MainActor
class ChatHistoryService: SuperLog {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = true
    
    static let shared = ChatHistoryService()

    private var modelContainer: ModelContainer?
    private let llmService = LLMService.shared

    private init() {}

    /// 使用外部容器初始化（从 App 初始化）
    func initializeWithContainer(_ container: ModelContainer) {
        self.modelContainer = container
        if Self.verbose {
            os_log("\(Self.t)✅ SwiftData 聊天存储已初始化")
        }
    }

    // MARK: - 保存对话

    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        guard let container = modelContainer else {
            os_log(.error, "\(Self.t)❌ 模型容器未初始化")
            return
        }

        let context = ModelContext(container)
        context.insert(conversation)

        do {
            try context.save()
        } catch {
            os_log(.error, "\(Self.t)❌ 保存对话失败：\(error.localizedDescription)")
        }
    }

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

        if Self.verbose {
            os_log("\(Self.t)✨ 创建新对话：\(title)")
        }

        return conversation
    }

    // MARK: - 更新对话标题

    /// 更新对话标题
    func updateConversationTitle(_ conversation: Conversation, newTitle: String) {
        conversation.title = newTitle
        conversation.updatedAt = Date()

        saveConversation(conversation)

        if Self.verbose {
            os_log("\(Self.t)✏️ 对话标题已更新：\(newTitle)")
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
                ChatMessage(role: .user, content: titlePrompt),
            ]

            let response = try await llmService.sendMessage(
                messages: titleMessages,
                config: titleConfig,
                tools: []
            )

            let generatedTitle = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // 确保标题长度合适
            if generatedTitle.count <= 20 {
                return generatedTitle
            } else {
                return String(generatedTitle.prefix(20))
            }
        } catch {
            os_log(.error, "\(Self.t)❌ 生成标题失败：\(error.localizedDescription)")
            // 降级：使用消息的前 20 个字符作为标题
            return String(trimmedMessage.prefix(20))
        }
    }

    // MARK: - 保存消息

    /// 保存消息到指定对话
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) {
        guard let container = modelContainer else {
            os_log(.error, "\(Self.t)❌ 模型容器未初始化")
            return
        }

        let context = ModelContext(container)

        // 创建消息实体
        let messageEntity = ChatMessageEntity.fromChatMessage(message)
        messageEntity.conversation = conversation

        context.insert(messageEntity)
        conversation.updatedAt = Date()

        do {
            try context.save()
            if Self.verbose {
                os_log("\(Self.t)💾 [\(conversation.id)] 消息已保存：\(message.content.max(100))")
            }
        } catch {
            os_log(.error, "\(Self.t)❌ 保存消息失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 加载对话

    /// 获取所有对话
    func fetchAllConversations() -> [Conversation] {
        guard let container = modelContainer else {
            os_log(.error, "\(Self.t)❌ 模型容器未初始化")
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let conversations = try context.fetch(descriptor)
            if Self.verbose {
                os_log("\(Self.t)📄 获取到 \(conversations.count) 个对话")
            }
            return conversations
        } catch {
            os_log(.error, "\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 根据 ID 获取对话
    func fetchConversation(id: UUID) -> Conversation? {
        guard let container = modelContainer else {
            os_log(.error, "\(Self.t)❌ 模型容器未初始化")
            return nil
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            let conversations = try context.fetch(descriptor)
            return conversations.first
        } catch {
            os_log(.error, "\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 获取项目相关的对话
    func fetchConversations(forProject projectId: String) -> [Conversation] {
        guard let container = modelContainer else {
            os_log(.error, "\(Self.t)❌ 模型容器未初始化")
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        do {
            let conversations = try context.fetch(descriptor)
            if Self.verbose {
                os_log("\(Self.t)📄 获取到项目 \(projectId) 的 \(conversations.count) 个对话")
            }
            return conversations
        } catch {
            os_log(.error, "\(Self.t)❌ 获取项目对话失败：\(error.localizedDescription)")
            return []
        }
    }

    /// 加载对话的消息
    func loadMessages(for conversation: Conversation) -> [ChatMessage] {
        // 直接从 conversation 的关系中获取消息，避免 SwiftData predicate 类型问题
        let messageEntities = conversation.messages.sorted { $0.timestamp < $1.timestamp }
        let messages = messageEntities.compactMap { $0.toChatMessage() }
        if Self.verbose {
            os_log("\(Self.t)📄 [\(conversation.id)] 加载到 \(messages.count) 条消息")
        }
        return messages
    }

    // MARK: - 删除对话

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        guard let container = modelContainer else {
            os_log(.error, "\(Self.t)❌ 模型容器未初始化")
            return
        }

        let context = ModelContext(container)
        context.delete(conversation)

        do {
            try context.save()
            if Self.verbose {
                os_log("\(Self.t)🗑️ 对话已删除：\(conversation.title)")
            }
        } catch {
            os_log(.error, "\(Self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 工具方法

    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer? {
        return modelContainer
    }
}
