import AgentToolKit
import Foundation
import LumiCoreKit
import SwiftData

/// 消息持久化服务 — 唯一负责 SwiftData 中 `ChatMessageEntity` 实体的读写。
///
/// ## 线程安全
///
/// 整个服务标记为 `@MainActor`，所有数据库操作都在主线程执行。
@MainActor
final class MessageService: SuperLog, Sendable {
    nonisolated static let emoji = "📨"
    nonisolated static let verbose: Bool = true

    let modelContainer: ModelContainer
    let modelContext: ModelContext
    private let conversationService: ConversationService

    struct ConversationTimelineSummary {
        let messageCount: Int
        let currentContextTokens: Int
    }

    init(conversationService: ConversationService, reason: String) {
        self.conversationService = conversationService
        self.modelContainer = conversationService.modelContainer
        self.modelContext = conversationService.modelContext
        if Self.verbose {
            AppLogger.core.info("\(Self.t)✅ (\(reason)) 消息存储已初始化")
        }
    }

    func getContext() -> ModelContext {
        modelContext
    }

    func getModelContainer() -> ModelContainer {
        modelContainer
    }
}

// MARK: - 消息保存

extension MessageService {

    /// 保存消息到指定对话
    @discardableResult
    func saveMessage(_ message: ChatMessage, to conversation: Conversation) -> ChatMessage? {
        saveMessage(message, toConversationId: conversation.id)
    }

    /// 保存消息
    ///
    /// 内置去重检查：如果相同 `id` 的消息已存在，则执行更新而非插入，
    /// 防止 SwiftData `Duplicate registration` 崩溃。
    @discardableResult
    func saveMessage(_ message: ChatMessage, toConversationId conversationId: UUID) -> ChatMessage? {
        let signpostID = UIPerformanceSignpost.begin("MessageService.saveMessage")
        defer { UIPerformanceSignpost.end("MessageService.saveMessage", signpostID) }

        let context = getContext()

        guard let fetchedConversation = conversationService.fetchConversation(id: conversationId) else {
            AppLogger.core.error("\(Self.t)❌ 无法找到对话")
            return nil
        }

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
                    if Self.verbose {
                        AppLogger.core.info("\(Self.t)messageSaved (update) role=\(message.role.rawValue) queue=\(queueLabel) id=\(message.id.uuidString.prefix(8))")
                    }
                    NotificationCenter.postMessageSaved(message: updated, conversationId: fetchedConversation.id)
                }
                return updated
            } catch {
                AppLogger.core.error("更新消息失败：\(error.localizedDescription)")
                return nil
            }
        }

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
                    AppLogger.core.debug("\(Self.t)新消息已保存: \(message.id)")
                }
                let queueLabel = message.queueStatus?.rawValue ?? "nil"
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)messageSaved role=\(message.role.rawValue) queue=\(queueLabel) id=\(message.id.uuidString.prefix(8))")
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
        let context = getContext()
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
    func deleteMessagesAsync(messageIds: [UUID], conversationId: UUID) async -> Int {
        guard !messageIds.isEmpty else { return 0 }

        let context = getContext()
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

    @discardableResult
    func updateMessage(_ message: ChatMessage, conversationId: UUID) -> ChatMessage? {
        saveMessage(message, toConversationId: conversationId)
    }
}

// MARK: - 消息查询

extension MessageService {

    /// 加载对话消息
    ///
    /// 直接查询 `ChatMessageEntity` 表，而不是通过 `Conversation.messages` 关系。
    func loadMessages(forConversationId conversationId: UUID) -> [ChatMessage]? {
        let context = getContext()

        guard conversationService.fetchConversation(id: conversationId) != nil else {
            AppLogger.core.error("\(Self.t) [\(conversationId)] 无法找到对话")
            return nil
        }

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
    func getConversationTimelineSummary(forConversationId conversationId: UUID) -> ConversationTimelineSummary {
        let context = getContext()

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

    /// 分页加载消息（从最新消息开始，按时间倒序）
    func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        let signpostID = UIPerformanceSignpost.begin("MessageService.loadMessagesPage")
        defer { UIPerformanceSignpost.end("MessageService.loadMessagesPage", signpostID) }

        let context = getContext()

        guard limit > 0 else {
            return ([], false)
        }

        var cursor = beforeTimestamp
        var collected: [ChatMessage] = []
        var hasMoreVisible = false

        let batchSize = max(limit * 3, limit + 10)
        let maxBatches = 20
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

            for entity in fetched {
                guard let msg = entity.toChatMessage(), msg.shouldDisplayInChatList() else {
                    continue
                }
                collected.append(msg)
                oldestVisibleTimestamp = msg.timestamp
                if collected.count >= limit {
                    break batchLoop
                }
            }

            if let oldest = oldestVisibleTimestamp {
                cursor = oldest
            } else if let lastTimestamp = fetched.last?.timestamp {
                cursor = lastTimestamp
            }

            if fetched.count < batchSize {
                hasMoreVisible = false
                break
            }
        }

        let pageMessagesDesc = Array(collected.prefix(limit))
        let messages = Array(pageMessagesDesc.reversed())

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
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        let context = getContext()

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

// MARK: - 消息队列

extension MessageService {

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

// MARK: - 关系同步（私有）

extension MessageService {

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

    private func syncToolCallRelations(
        for entity: ChatMessageEntity,
        with message: ChatMessage,
        in context: ModelContext
    ) {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else {
            if !entity.toolCalls.isEmpty {
                for existing in entity.toolCalls {
                    context.delete(existing)
                }
                entity.toolCalls = []
            }
            return
        }

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

        let newIDs = Set(toolCalls.map { $0.id })
        for existing in entity.toolCalls where !newIDs.contains(existing.id) {
            context.delete(existing)
        }

        entity.toolCalls = syncedEntities
    }

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
