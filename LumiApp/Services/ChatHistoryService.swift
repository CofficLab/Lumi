import Foundation
import AgentToolKit
import SwiftData
import LLMKit
import LumiCoreKit

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
    nonisolated static let verbose: Bool = false // 链路日志见 AgentSendPipelineLog
    let conversationService: ConversationService
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let llmService: LLMService

    struct ConversationTimelineSummary {
        let messageCount: Int
        let currentContextTokens: Int
    }

    /// 使用 LLM 服务和对话服务初始化（共享同一 `ModelContext`）
    init(llmService: LLMService, conversationService: ConversationService, reason: String) {
        self.llmService = llmService
        self.conversationService = conversationService
        self.modelContainer = conversationService.modelContainer
        self.modelContext = conversationService.modelContext
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

// MARK: - 对话标题生成

extension ChatHistoryService {

    /// 基于用户消息生成会话标题
    func generateConversationTitle(from userMessage: String, config: LLMConfig) async -> String {
        await ConversationTitleGenerator().generate(userMessage: userMessage, config: config) { [llmService] messages, config in
            try await llmService.sendMessage(messages: messages, config: config, tools: [])
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

        guard let fetchedConversation = conversationService.fetchConversation(id: conversationId) else {
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
            conversationService.touchUpdatedAt(forConversationId: conversationId)

            do {
                try context.save()
                let updated = existingEntity.toChatMessage()
                if let updated {
                    if Self.verbose {
                        AppLogger.core.info("\(Self.t)✅ 同步 ID 消息已更新: \(message.id)")
                    }
                    let queueLabel = message.queueStatus?.rawValue ?? "nil"
        if AgentSendPipelineLog.enabled {
                        AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(fetchedConversation.id))] 💾 [DB] messageSaved (update) role=\(message.role.rawValue) queue=\(queueLabel) id=\(message.id.uuidString.prefix(8))")
                    }
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
        messageEntity.conversation = fetchedConversation
        syncToolCallRelations(for: messageEntity, with: message, in: context)
        syncImageRelations(for: messageEntity, with: message, in: context)
        conversationService.touchUpdatedAt(forConversationId: conversationId)
        context.insert(messageEntity)

        do {
            try context.save()
            if let savedMessage = messageEntity.toChatMessage() {
                if Self.verbose {
                    AppLogger.core.debug("\(Self.t)💾 [\(conversationId)] 新消息已保存: \(message.id)")
                }
                let queueLabel = message.queueStatus?.rawValue ?? "nil"
        if AgentSendPipelineLog.enabled {
                    AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] 💾 [DB] messageSaved role=\(message.role.rawValue) queue=\(queueLabel) id=\(message.id.uuidString.prefix(8))")
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

        guard conversationService.fetchConversation(id: conversationId) != nil else {
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
            var probeCursor = oldest
            hasMoreVisible = false

            while true {
                var probeDescriptor = FetchDescriptor<ChatMessageEntity>(
                    predicate: #Predicate<ChatMessageEntity> { msg in
                        msg.conversation?.id == conversationId && msg.timestamp < probeCursor
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
                )
                probeDescriptor.fetchLimit = batchSize

                guard let probeFetched = try? context.fetch(probeDescriptor),
                      !probeFetched.isEmpty else {
                    break
                }

                let probeMessages = probeFetched.compactMap { $0.toChatMessage() }
                if probeMessages.contains(where: { $0.shouldDisplayInChatList() }) {
                    hasMoreVisible = true
                    break
                }

                guard probeFetched.count == batchSize,
                      let nextCursor = probeFetched.last?.timestamp,
                      nextCursor < probeCursor else {
                    break
                }
                probeCursor = nextCursor
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

// MARK: - 消息更新

extension ChatHistoryService {

    @discardableResult
    func updateMessage(_ message: ChatMessage, conversationId: UUID) -> ChatMessage? {
        saveMessage(message, toConversationId: conversationId)
    }
}

// MARK: - Message Queue (DB)

extension ChatHistoryService {

    /// 指定会话中 queueStatus == pending 的消息（按时间升序）。
    func pendingMessages(forConversationId conversationId: UUID) -> [ChatMessage] {
        let context = getContext()
        let pendingRaw = MessageQueueStatus.pending.rawValue
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId && msg.queueStatus == pendingRaw
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? context.fetch(descriptor))?.compactMap { $0.toChatMessage() } ?? []
    }

    /// 取出最早 pending user 消息并标记为 processing。
    @discardableResult
    func dequeueNextPendingMessage(forConversationId conversationId: UUID) -> ChatMessage? {
        let context = getContext()
        let pendingRaw = MessageQueueStatus.pending.rawValue
        let userRole = MessageRole.user.rawValue
        var descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId
                    && msg.queueStatus == pendingRaw
                    && msg._role == userRole
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = 1

        guard let entity = try? context.fetch(descriptor).first else { return nil }

        entity.queueStatus = MessageQueueStatus.processing.rawValue
        try? context.save()
        if let updated = entity.toChatMessage() {
        if AgentSendPipelineLog.enabled {
                AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] 💾 [DB] dequeue pending→processing id=\(updated.id.uuidString.prefix(8))")
            }
            NotificationCenter.postMessageSaved(message: updated, conversationId: conversationId)
            return updated
        }
        return nil
    }

    /// Turn 结束时清除 processing 队列标记。
    func clearQueueStatus(forConversationId conversationId: UUID) {
        let context = getContext()
        let processingRaw = MessageQueueStatus.processing.rawValue
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId && msg.queueStatus == processingRaw
            }
        )
        guard let entities = try? context.fetch(descriptor) else { return }
        for entity in entities {
            entity.queueStatus = nil
        }
        try? context.save()
    }

    /// 移除 pending 消息（用户从待发送列表删除）。
    @discardableResult
    func removePendingMessage(id messageId: UUID, conversationId: UUID) -> Bool {
        let context = getContext()
        let pendingRaw = MessageQueueStatus.pending.rawValue
        var descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.id == messageId && msg.queueStatus == pendingRaw
            }
        )
        descriptor.fetchLimit = 1
        guard let entity = try? context.fetch(descriptor).first,
              entity.conversation?.id == conversationId else { return false }
        context.delete(entity)
        try? context.save()
        return true
    }
}
