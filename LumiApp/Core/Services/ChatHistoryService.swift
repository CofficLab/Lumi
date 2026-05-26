import Foundation
import AgentToolKit
import SwiftData
import LLMKit

// MARK: - 通知常量

extension Notification.Name {
    static let conversationDidChange = Notification.Name("ChatHistoryService.ConversationDidChange")
}

enum ConversationChangeType: String {
    case created
    case updated
    case deleted
}

enum ConversationChangeUserInfoKey {
    static let type = "type"
    static let conversationId = "conversationId"
}

// MARK: - ToolCall / ChatMessage 便捷扩展

extension ToolCall {
    /// 将嵌入在 ToolCall 中的结果投影为 LLM 所需的 `role: .tool` 消息。
    func projectedToolOutputMessage(conversationId: UUID) -> ChatMessage? {
        guard let result else { return nil }
        return ChatMessage(
            role: .tool,
            conversationId: conversationId,
            content: result.content,
            isError: result.isError,
            toolCallID: id,
            images: result.images
        )
    }
}

extension ChatMessage {
    /// 发送给 LLM 时使用的 assistant 消息副本（不包含嵌入的工具结果）。
    func forLLMAssistantMessage() -> ChatMessage {
        var message = self
        if let toolCalls {
            message.toolCalls = toolCalls.map {
                ToolCall(
                    id: $0.id,
                    name: $0.name,
                    arguments: $0.arguments,
                    authorizationState: $0.authorizationState
                )
            }
        }
        return message
    }
}

// MARK: - ChatHistoryService

/// 聊天历史服务 - 使用 SwiftData 存储对话
///
/// ## 线程安全
///
/// 整个服务标记为 `@MainActor`，所有数据库操作都在主线程执行，
/// 消除 `Unbinding from the main queue` 警告和跨线程竞态。
@MainActor
final class ChatHistoryService: SuperLog, Sendable {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = true
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let llmService: LLMService

    struct ConversationTimelineSummary {
        let messageCount: Int
        let currentContextTokens: Int
    }

    /// 使用 LLM 服务和模型容器初始化
    init(llmService: LLMService, modelContainer: ModelContainer, reason: String) {
        self.llmService = llmService
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 聊天存储已初始化")
        }
    }

    /// 获取模型上下文
    internal func getContext() -> ModelContext {
        return modelContext
    }

    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer {
        return modelContainer
    }
}

// MARK: - 对话创建

extension ChatHistoryService {

    /// 创建新对话
    func createConversation(projectId: String? = nil, title: String = "", chatMode: String? = nil) -> Conversation {
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
}

// MARK: - 对话查询

extension ChatHistoryService {

    /// 获取所有对话（按更新时间倒序）
    func fetchAllConversations() -> [Conversation] {
        let context = self.getContext()
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
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
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
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

    /// 获取最流行的供应商和模型（基于对话历史分析）
    ///
    /// 统计所有设置了模型偏好的对话，返回使用次数最多的供应商和模型组合。
    /// - Returns: 最流行的 (providerId, model) 组合，如果没有任何对话设置了偏好则返回 nil
    func fetchMostPopularModelPreference() -> (providerId: String, model: String)? {
        let context = self.getContext()

        // 拉取所有设置了模型偏好的对话
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.providerId != nil && $0.model != nil },
            sortBy: []
        )

        guard let conversations = try? context.fetch(descriptor), !conversations.isEmpty else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 无对话记录设置模型偏好")
            }
            return nil
        }

        // 统计 (providerId, model) 组合的出现次数
        var usageCount: [String: Int] = [:]
        for conversation in conversations {
            guard let providerId = conversation.providerId,
                  let model = conversation.model else {
                continue
            }
            let key = "\(providerId)|\(model)"
            usageCount[key] = (usageCount[key] ?? 0) + 1
        }

        // 找出使用次数最多的组合
        guard let topKey = usageCount.max(by: { $0.value < $1.value })?.key else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📊 无法确定最流行的模型偏好")
            }
            return nil
        }

        let components = topKey.split(separator: "|", maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }

        let result = (providerId: String(components[0]), model: String(components[1]))

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📊 最流行模型偏好：\(result.providerId) - \(result.model)（使用 \(usageCount[topKey] ?? 0) 次）")
        }

        return result
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

// MARK: - 对话更新

extension ChatHistoryService {

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

    /// 更新对话的响应详细程度偏好
    /// - Parameters:
    ///   - conversation: 目标对话
    ///   - verbosity: 详细程度 rawValue，nil 表示清除对话级偏好（回退到全局偏好）
    func updateVerbosity(_ conversation: Conversation, verbosity: String?) {
        conversation.verbosity = verbosity
        conversation.updatedAt = Date()

        saveConversation(conversation)

        if Self.verbose {
            if let verbosity {
                AppLogger.core.info("\(Self.t)📝 已保存对话 '\(conversation.title)' 的详细程度：\(verbosity)")
            } else {
                AppLogger.core.info("\(Self.t)📝 已清除对话 '\(conversation.title)' 的详细程度")
            }
        }
    }
}

// MARK: - 对话存储与删除

extension ChatHistoryService {

    /// 保存或更新对话
    func saveConversation(_ conversation: Conversation) {
        let context = self.getContext()
        context.insert(conversation)

        do {
            try context.save()
        } catch {
            AppLogger.core.error("\(Self.t)❌ 保存对话失败：\(error.localizedDescription)")
        }
    }

    func notifyConversationChanged(type: ConversationChangeType, conversationId: UUID) {
        let userInfo: [String: String] = [
            ConversationChangeUserInfoKey.type: type.rawValue,
            ConversationChangeUserInfoKey.conversationId: conversationId.uuidString,
        ]

        let postOnCurrentThread = {
            NotificationCenter.default.post(
                name: .conversationDidChange,
                object: nil,
                userInfo: userInfo
            )
        }

        if Thread.isMainThread {
            postOnCurrentThread()
        } else {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .conversationDidChange,
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }

    /// 删除对话
    func deleteConversation(_ conversation: Conversation) {
        let context = self.getContext()
        context.delete(conversation)

        do {
            try context.save()
            notifyConversationChanged(type: .deleted, conversationId: conversation.id)
            NotificationCenter.postConversationDeleted(conversationId: conversation.id)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 对话已删除：\(conversation.title)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - 消息保存

extension ChatHistoryService {

    /// 保存消息到指定对话
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversation: 对话对象
    /// - Returns: 保存后的消息（从数据库重新加载）
    @discardableResult
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) -> ChatMessage? {
        return saveMessage(message, toConversationId: conversation.id)
    }

    /// 保存消息
    ///
    /// 内置去重检查：如果相同 `id` 的消息已存在，则执行更新而非插入，
    /// 防止 SwiftData `Duplicate registration` 崩溃。
    ///
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversationId: 对话 ID
    /// - Returns: 保存后的消息
    @discardableResult
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: UUID) -> ChatMessage? {
        let signpostID = UIPerformanceSignpost.begin("ChatHistory.saveMessage")
        defer { UIPerformanceSignpost.end("ChatHistory.saveMessage", signpostID) }

        let context = self.getContext()
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        descriptor.fetchLimit = 1

        guard let fetchedConversation = try? context.fetch(descriptor).first else {
            AppLogger.core.error("\(Self.t)❌ 无法找到对话")
            return nil
        }

        // 去重检查：如果相同 ID 的消息已存在，执行更新而非插入
        var existingDescriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { $0.id == message.id }
        )
        existingDescriptor.fetchLimit = 1

        if let existingEntity = try? context.fetch(existingDescriptor).first {
            AppLogger.core.warning("\(Self.t)⚠️ 检测到相同 ID 的消息已存在: \(message.id)")

            existingEntity.apply(from: message, in: context)
            existingEntity.conversation = fetchedConversation
            syncToolCallRelations(for: existingEntity, with: message, in: context)
            syncImageRelations(for: existingEntity, with: message, in: context)
            fetchedConversation.updatedAt = Date()

            do {
                try context.save()
                let updated = existingEntity.toChatMessage()
                if let updated {
                    AppLogger.core.info("\(Self.t)✅ 同步 ID 消息已更新: \(message.id)")
                    NotificationCenter.postMessageSaved(message: updated, conversationId: fetchedConversation.id)
                }
                return updated
            } catch {
                AppLogger.core.error("\(Self.t)❌ 更新消息失败：\(error.localizedDescription)")
                return nil
            }
        }

        // 消息不存在，创建新记录
        let messageEntity = ChatMessageEntity.fromChatMessage(message, in: context)
        messageEntity.timestamp = Date()
        messageEntity.conversation = fetchedConversation
        syncToolCallRelations(for: messageEntity, with: message, in: context)
        syncImageRelations(for: messageEntity, with: message, in: context)
        fetchedConversation.updatedAt = Date()
        context.insert(messageEntity)

        do {
            try context.save()
            if let savedMessage = messageEntity.toChatMessage() {
                if Self.verbose {
                    AppLogger.core.debug("\(Self.t)💾 [\(conversationId)] 新消息已保存: \(message.id)")
                }
                NotificationCenter.postMessageSaved(message: savedMessage, conversationId: fetchedConversation.id)
                return savedMessage
            }
            return nil
        } catch {
            AppLogger.core.error("\(Self.t)❌ 保存消息失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 按消息 ID 更新已存在的消息（同 `id` 覆盖字段，不插入新行）
    func updateMessageAsync(_ message: ChatMessage, conversationId: UUID) async -> ChatMessage? {
        let context = self.getContext()
        var descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { $0.id == message.id }
        )
        descriptor.fetchLimit = 1

        guard let entity = try? context.fetch(descriptor).first else {
            return nil
        }

        guard entity.conversation?.id == conversationId else {
            return nil
        }

        entity.apply(from: message, in: context)
        syncToolCallRelations(for: entity, with: message, in: context)
        syncImageRelations(for: entity, with: message, in: context)

        do {
            try context.save()
            let updated = entity.toChatMessage()
            if let updated {
                NotificationCenter.postMessageSaved(message: updated, conversationId: conversationId)
            }
            return updated
        } catch {
            AppLogger.core.error("\(Self.t)❌ 更新消息失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 批量删除消息
    /// - Parameters:
    ///   - messageIds: 要删除的消息 ID 列表
    ///   - conversationId: 对话 ID（用于校验归属）
    /// - Returns: 实际删除的消息数量
    func deleteMessagesAsync(messageIds: [UUID], conversationId: UUID) async -> Int {
        guard !messageIds.isEmpty else { return 0 }

        let context = self.getContext()
        let idSet = Set(messageIds)
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let entities = try? context.fetch(descriptor) else {
            return 0
        }

        var deletedCount = 0
        for entity in entities where idSet.contains(entity.id) {
            context.delete(entity)
            deletedCount += 1
        }

        do {
            try context.save()
            // 清理不再被任何消息引用的孤立图片
            cleanupOrphanedImages(in: context)
            try context.save()
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ [\(conversationId)] 已删除 \(deletedCount) 条消息")
            }
            return deletedCount
        } catch {
            AppLogger.core.error("\(Self.t)❌ 删除消息失败：\(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - 消息加载

extension ChatHistoryService {

    /// 加载对话消息
    ///
    /// 直接查询 `ChatMessageEntity` 表，而不是通过 `Conversation.messages` 关系。
    /// 这是因为 SwiftData 的 `@Relationship` 在通过 `FetchDescriptor` 重新 fetch
    /// 父对象后，关系属性可能不会正确加载（返回空数组）。
    /// 直接查询子表可以可靠地获取所有消息。
    ///
    /// - Parameter conversationId: 对话 ID
    /// - Returns: 消息列表；若会话不存在返回 nil
    func loadMessages(forConversationId conversationId: UUID) -> [ChatMessage]? {
        let context = self.getContext()

        // 先验证会话是否存在
        let conversationDescriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )
        guard let _ = try? context.fetch(conversationDescriptor).first else {
            AppLogger.core.error("\(Self.t) [\(conversationId)] 无法找到对话")
            return nil
        }

        // 直接查询 ChatMessageEntity 表，绕过 @Relationship
        let messageDescriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let messageEntities = try? context.fetch(messageDescriptor) else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) [\(conversationId)] 加载到 0 条消息")
            }
            return []
        }

        let messages = messageEntities.compactMap { $0.toChatMessage() }
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ [\(conversationId)] 加载到 \(messages.count) 条消息")
        }
        return messages
    }

    /// 加载对话的消息
    func loadMessages(for conversation: Conversation) -> [ChatMessage] {
        let context = getContext()

        // 直接查询 ChatMessageEntity 表，绕过 @Relationship
        let conversationId = conversation.id
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let entities = try? context.fetch(descriptor) else {
            AppLogger.core.error("\(Self.t)❌ 加载消息失败")
            return []
        }

        let messages = entities.compactMap { $0.toChatMessage() }
        if Self.verbose {
            AppLogger.core.info("\(Self.t)📄 [\(conversationId)] 加载到 \(messages.count) 条消息")
        }
        return messages
    }

    /// 获取对话时间线状态栏所需的轻量统计信息。
    ///
    /// 避免状态栏为了展示消息数和上下文 token 而全量加载并转换当前会话消息。
    func getConversationTimelineSummary(forConversationId conversationId: UUID) -> ConversationTimelineSummary {
        let context = self.getContext()

        let countDescriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { message in
                message.conversation?.id == conversationId
            }
        )
        let messageCount = (try? context.fetchCount(countDescriptor)) ?? 0

        var lastAssistantDescriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { message in
                message.conversation?.id == conversationId && message._role == "assistant"
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        lastAssistantDescriptor.fetchLimit = 1

        guard let lastAssistant = try? context.fetch(lastAssistantDescriptor).first else {
            return ConversationTimelineSummary(
                messageCount: messageCount,
                currentContextTokens: 0
            )
        }

        let baseContext = lastAssistant.metrics?.inputTokens ?? 0
        let lastAssistantTimestamp = lastAssistant.timestamp
        let userAfterAssistantDescriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { message in
                message.conversation?.id == conversationId &&
                    message._role == "user" &&
                    message.timestamp > lastAssistantTimestamp
            }
        )

        let newTokens = ((try? context.fetch(userAfterAssistantDescriptor)) ?? [])
            .reduce(0) { total, message in
                total + message.content.count / 4
            }

        return ConversationTimelineSummary(
            messageCount: messageCount,
            currentContextTokens: baseContext + newTokens
        )
    }

    /// 分页加载消息（从最新消息开始，按时间倒序；直接按消息分页，避免加载整会话）
    /// - Parameters:
    ///   - conversationId: 对话 ID
    ///   - limit: 每页数量
    ///   - beforeTimestamp: 加载此时间戳之前的消息（nil 表示从最新开始）
    /// - Returns: (消息列表, 是否还有更多)
    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        let signpostID = UIPerformanceSignpost.begin("ChatHistory.loadMessagesPage")
        defer { UIPerformanceSignpost.end("ChatHistory.loadMessagesPage", signpostID) }

        let context = self.getContext()

        guard limit > 0 else {
            return ([], false)
        }

        // 下沉"是否展示"的过滤逻辑：此 API 只返回应该展示的消息，
        // 并在分页时自动跳过被过滤的消息，避免 UI 端再做判断和跳页。
        var cursor = beforeTimestamp
        var collected: [ChatMessage] = []
        var hasMoreVisible = false

        // 批次大小：尽量减少 fetch 次数，但也避免一次拉太多
        let batchSize = max(limit * 3, limit + 10)
        // 安全阈值：避免极端情况下长时间循环（例如大量连续 tool output 被过滤）
        let maxBatches = 20
        // 记录当前页中"最旧"的一条可见消息时间戳，用于作为下一页游标
        var oldestVisibleTimestamp: Date?

        batchLoop: for _ in 0 ..< maxBatches {
            var descriptor: FetchDescriptor<ChatMessageEntity>
            if let before = cursor {
                descriptor = FetchDescriptor<ChatMessageEntity>(
                    predicate: #Predicate<ChatMessageEntity> { msg in
                        msg.conversation?.id == conversationId && msg.timestamp < before
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<ChatMessageEntity>(
                    predicate: #Predicate<ChatMessageEntity> { msg in
                        msg.conversation?.id == conversationId
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
            }
            descriptor.fetchLimit = batchSize

            guard let fetched = try? context.fetch(descriptor), !fetched.isEmpty else {
                hasMoreVisible = false
                break
            }

            // fetched 按 timestamp desc（从新到旧）；我们按从新到旧遍历，
            // 收集到 limit 条后，再在返回时整体反转为从旧到新，保证 UI 底部是最新消息。
            for entity in fetched {
                guard let msg = entity.toChatMessage(), msg.shouldDisplayInChatList() else {
                    continue
                }
                collected.append(msg)
                oldestVisibleTimestamp = msg.timestamp
                if collected.count >= limit {
                    // 当前页已满，停止继续拉取 batch
                    break batchLoop
                }
            }

            // 这一批没收集满，继续下一批。
            // 如果这一批有可展示消息，则游标设为当前已收集的"最旧"可展示消息；
            // 否则使用本批次中最旧原始消息的时间戳推进游标，避免死循环。
            if let oldest = oldestVisibleTimestamp {
                cursor = oldest
            } else if let lastTimestamp = fetched.last?.timestamp {
                cursor = lastTimestamp
            }

            // 如果 fetched 少于 batchSize，说明原始数据也快到底了
            if fetched.count < batchSize {
                hasMoreVisible = false
                break
            }
        }

        // collected 当前是从新到旧（最新在前），为了让 UI 底部是最新消息，
        // 这里统一转换为从旧到新（最旧在前，最新在后）。
        let pageMessagesDesc = Array(collected.prefix(limit))
        let messages = Array(pageMessagesDesc.reversed())

        // 探测是否还有更多可展示消息：从当前页最旧一条消息再往前探一小批。
        if let oldest = oldestVisibleTimestamp {
            var probeDescriptor: FetchDescriptor<ChatMessageEntity>
            probeDescriptor = FetchDescriptor<ChatMessageEntity>(
                predicate: #Predicate<ChatMessageEntity> { msg in
                    msg.conversation?.id == conversationId && msg.timestamp < oldest
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            probeDescriptor.fetchLimit = max(10, min(30, batchSize))
            if let probeFetched = try? context.fetch(probeDescriptor) {
                let probeConverted = probeFetched.compactMap { $0.toChatMessage() }
                hasMoreVisible = probeConverted.contains(where: { $0.shouldDisplayInChatList() })
            } else {
                hasMoreVisible = false
            }
        } else {
            hasMoreVisible = false
        }

        let hasMore = hasMoreVisible

        if Self.verbose {
            AppLogger.core.info("\(Self.t)📄 [\(conversationId)] 分页加载消息: \(messages.count) 条, hasMore: \(hasMore)")
        }

        return (messages, hasMore)
    }

    /// 获取会话消息总数
    /// - Parameter conversationId: 对话 ID
    /// - Returns: 消息数量
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        let context = self.getContext()

        // 直接让 SwiftData 计数可展示角色，避免把大对话全量 fetch 到主线程再转换过滤。
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId &&
                    (
                        msg._role == "user" ||
                        msg._role == "assistant" ||
                        msg._role == "status" ||
                        msg._role == "error"
                    )
            }
        )

        return (try? context.fetchCount(descriptor)) ?? 0
    }
}

// MARK: - 消息展开（LLM 上下文）

extension ChatHistoryService {

    /// 将存储中的 assistant/toolCalls 展开为 LLM 可消费的完整消息序列。
    func expandMessagesForLLM(_ messages: [ChatMessage]) -> [ChatMessage] {
        var expanded: [ChatMessage] = []

        for message in messages {
            switch message.role {
            case .tool:
                // 独立的 tool 消息（投影产生的）
                if message.shouldSendToLLM {
                    expanded.append(message)
                }
            case .assistant:
                expanded.append(message.forLLMAssistantMessage())
                if let toolCalls = message.toolCalls {
                    for toolCall in toolCalls {
                        if let projected = toolCall.projectedToolOutputMessage(conversationId: message.conversationId) {
                            expanded.append(projected)
                        }
                    }
                }
            default:
                if message.shouldSendToLLM {
                    expanded.append(message)
                }
            }
        }

        return expanded
    }

    /// 加载会话消息并展开为 LLM 上下文。
    func loadMessagesExpandedForLLM(forConversationId conversationId: UUID) -> [ChatMessage]? {
        guard let messages = loadMessages(forConversationId: conversationId) else { return nil }
        return expandMessagesForLLM(messages)
    }
}

// MARK: - 关系同步（私有）

extension ChatHistoryService {

    /// 同步消息实体与图片附件的关系
    ///
    /// 将 ChatMessage 中的 ImageAttachment 转换为 ImageAttachmentEntity，
    /// 并建立与 ChatMessageEntity 的关系。支持按 id 去重。
    private func syncImageRelations(
        for entity: ChatMessageEntity,
        with message: ChatMessage,
        in context: ModelContext
    ) {
        guard !message.images.isEmpty else {
            entity.images = []
            return
        }

        let imageEntities = message.images.map { attachment in
            // 检查是否已存在（按 id 去重）
            var descriptor = FetchDescriptor<ImageAttachmentEntity>(
                predicate: #Predicate<ImageAttachmentEntity> { $0.id == attachment.id }
            )
            descriptor.fetchLimit = 1
            if let existing = try? context.fetch(descriptor).first {
                return existing
            }
            let newEntity = ImageAttachmentEntity.from(attachment)
            context.insert(newEntity)
            return newEntity
        }

        entity.images = imageEntities
    }

    /// 清理不再被任何消息引用的孤立图片
    func cleanupOrphanedImages(in context: ModelContext) {
        let descriptor = FetchDescriptor<ImageAttachmentEntity>()
        guard let allImages = try? context.fetch(descriptor) else { return }

        for image in allImages {
            let hasMessages = !(image.messages?.isEmpty ?? true)
            let hasToolResults = !(image.toolCallResults?.isEmpty ?? true)
            if !hasMessages && !hasToolResults {
                context.delete(image)
            }
        }
    }

    /// 同步消息实体与工具调用的关系
    ///
    /// 将 ChatMessage 中的 ToolCall 列表转换为 ToolCallEntity，
    /// 并建立与 ChatMessageEntity 的关系。支持按 id 去重和增量更新。
    private func syncToolCallRelations(
        for entity: ChatMessageEntity,
        with message: ChatMessage,
        in context: ModelContext
    ) {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else {
            // 消息没有工具调用，清空已有关系
            if !entity.toolCalls.isEmpty {
                for existing in entity.toolCalls {
                    context.delete(existing)
                }
                entity.toolCalls = []
            }
            return
        }

        // 构建"已有实体"的 id → entity 映射，方便按 id 增量更新
        var existingByID: [String: ToolCallEntity] = [:]
        for existing in entity.toolCalls {
            existingByID[existing.id] = existing
        }

        var syncedEntities: [ToolCallEntity] = []

        for toolCall in toolCalls {
            if let existing = existingByID[toolCall.id] {
                existing.apply(from: toolCall)
                syncToolCallResultImages(for: existing, with: toolCall, in: context)
                syncedEntities.append(existing)
            } else {
                let newEntity = ToolCallEntity.from(toolCall)
                newEntity.message = entity
                context.insert(newEntity)
                syncToolCallResultImages(for: newEntity, with: toolCall, in: context)
                syncedEntities.append(newEntity)
            }
        }

        // 删除不再需要的旧实体
        let newIDs = Set(toolCalls.map { $0.id })
        for existing in entity.toolCalls where !newIDs.contains(existing.id) {
            context.delete(existing)
        }

        entity.toolCalls = syncedEntities
    }

    /// 同步工具调用结果中的图片附件
    private func syncToolCallResultImages(
        for entity: ToolCallEntity,
        with toolCall: ToolCall,
        in context: ModelContext
    ) {
        let images = toolCall.result?.images ?? []
        guard !images.isEmpty else {
            entity.resultImages = []
            return
        }

        entity.resultImages = images.map { attachment in
            var descriptor = FetchDescriptor<ImageAttachmentEntity>(
                predicate: #Predicate<ImageAttachmentEntity> { $0.id == attachment.id }
            )
            descriptor.fetchLimit = 1
            if let existing = try? context.fetch(descriptor).first {
                return existing
            }
            let newEntity = ImageAttachmentEntity.from(attachment)
            context.insert(newEntity)
            return newEntity
        }
    }
}
