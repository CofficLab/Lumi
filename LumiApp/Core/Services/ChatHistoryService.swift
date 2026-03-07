import Foundation
import MagicKit
import OSLog
import SwiftData

/// 聊天历史服务 - 使用 SwiftData 存储对话
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = true

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let llmService: LLMService

    /// 使用 LLM 服务和模型容器初始化
    init(llmService: LLMService, modelContainer: ModelContainer) {
        self.llmService = llmService
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        if Self.verbose {
            os_log("\(Self.t)✅ 聊天存储已初始化")
        }
    }

    /// 获取模型上下文
    private func getContext() -> ModelContext {
        return modelContext
    }

    // MARK: - 保存对话

    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        let context = getContext()
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

    /// 自动为对话生成标题（如果需要）
    ///
    /// 检查对话是否满足生成标题的条件，如果满足则自动生成并保存
    ///
    /// - Parameters:
    ///   - conversationId: 对话 ID
    ///   - userMessageContent: 用户消息内容
    ///   - config: LLM 配置
    func autoGenerateConversationTitleIfNeeded(
        conversationId: UUID,
        userMessageContent: String,
        config: LLMConfig
    ) async {
        // 检查是否满足生成标题的条件
        let trimmedMessage = userMessageContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 消息内容为空，跳过生成标题")
            }
            return
        }

        // 获取对话信息
        guard let conversation = fetchConversation(id: conversationId) else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 对话 \(conversationId) 不存在，跳过生成标题")
            }
            return
        }
        
        // 检查标题是否还是默认的 "新会话 "
        guard conversation.title.hasPrefix("新会话 ") else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 对话已有自定义标题，跳过生成标题")
            }
            return
        }

        if Self.verbose {
            os_log("\(Self.t)🎯 [\(conversationId)] 开始为对话自动生成标题...")
        }

        // 生成标题
        let title = await generateConversationTitle(from: trimmedMessage, config: config)

        // 再次检查并更新对话标题（避免并发修改）
        guard let freshConversation = fetchConversation(id: conversationId),
              freshConversation.title.hasPrefix("新会话 ") else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 对话标题已被修改，放弃更新")
            }
            return
        }
        
        updateConversationTitle(freshConversation, newTitle: title)
        
        if Self.verbose {
            os_log("\(Self.t)✅ 对话标题已生成：\(title)")
        }
    }

    // MARK: - 保存消息

    /// 保存消息到指定对话
    /// - Returns: 保存后的消息（从数据库重新加载）
    @discardableResult
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) -> ChatMessage? {
        let context = getContext()

        // 创建消息实体
        let messageEntity = ChatMessageEntity.fromChatMessage(message)

        // 重新获取 conversation 以确保在当前上下文中
        let conversationId = conversation.id
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        guard let fetchedConversation = try? context.fetch(descriptor).first else {
            os_log(.error, "\(Self.t)❌ 无法在当前上下文中找到对话")
            return nil
        }

        messageEntity.conversation = fetchedConversation
        fetchedConversation.updatedAt = Date()

        context.insert(messageEntity)

        do {
            try context.save()
            if Self.verbose {
                let hasThinking = message.thinkingContent != nil && !message.thinkingContent!.isEmpty
                let metrics = [
                    message.inputTokens.map { "输入: \($0)" },
                    message.outputTokens.map { "输出: \($0)" },
                    message.totalTokens.map { "总计: \($0)" },
                    message.latency.map { "耗时: \(String(format: "%.0f", $0))ms" }
                ].compactMap { $0 }.joined(separator: ", ")
                os_log("\(Self.t)💾 [\(conversation.id)] 消息已保存：\(message.content.max(10)), 指标: [\(metrics)], 思考过程: \(hasThinking)")
            }
            // 返回保存后的消息
            return messageEntity.toChatMessage()
        } catch {
            os_log(.error, "\(Self.t)❌ 保存消息失败：\(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 加载对话

    /// 获取所有对话
    func fetchAllConversations() -> [Conversation] {
        let context = getContext()
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
        let context = getContext()
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
        let context = getContext()
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
        let context = getContext()

        // 重新获取 conversation 以确保在当前上下文中
        let conversationId = conversation.id
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        guard let fetchedConversation = try? context.fetch(descriptor).first else {
            os_log(.error, "\(Self.t)❌ 无法在当前上下文中找到对话")
            return []
        }

        // 从关系中获取消息
        let messageEntities = fetchedConversation.messages.sorted { $0.timestamp < $1.timestamp }
        let messages = messageEntities.compactMap { $0.toChatMessage() }
        if Self.verbose {
            os_log("\(Self.t)📄 [\(conversation.id)] 加载到 \(messages.count) 条消息")
        }
        return messages
    }

    // MARK: - 删除对话

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        let context = getContext()
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

    // MARK: - 性能统计

    /// 获取每个供应商和模型的平均耗时
    /// - Returns: 字典，键为 (providerId, modelName)，值为平均耗时（毫秒）
    func getModelLatencyStats() -> [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] {
        let context = getContext()
        
        // 获取所有有 latency 数据的消息
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.latency != nil && $0.providerId != nil && $0.modelName != nil }
        )

        guard let messageEntities = try? context.fetch(descriptor) else {
            os_log(.error, "\(Self.t)❌ 获取消息失败")
            return []
        }

        // 按 providerId 和 modelName 分组统计
        var statsDict: [String: [String: (total: Double, count: Int)]] = [:]
        
        for entity in messageEntities {
            guard let providerId = entity.providerId,
                  let modelName = entity.modelName,
                  let latency = entity.latency else {
                continue
            }
            
            if statsDict[providerId] == nil {
                statsDict[providerId] = [:]
            }
            
            var existing = statsDict[providerId]?[modelName] ?? (total: 0, count: 0)
            existing.total += latency
            existing.count += 1
            statsDict[providerId]?[modelName] = existing
        }

        // 转换为数组并计算平均值
        var result: [(providerId: String, modelName: String, avgLatency: Double, sampleCount: Int)] = []
        
        for (providerId, models) in statsDict {
            for (modelName, stats) in models {
                let avgLatency = stats.count > 0 ? stats.total / Double(stats.count) : 0
                result.append((providerId: providerId, modelName: modelName, avgLatency: avgLatency, sampleCount: stats.count))
            }
        }

        // 按 providerId 和 modelName 排序
        result.sort {
            if $0.providerId != $1.providerId {
                return $0.providerId < $1.providerId
            }
            return $0.modelName < $1.modelName
        }
        
        return result
    }

    // MARK: - 工具方法

    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer {
        return modelContainer
    }
}
