import Foundation
import SwiftData

// MARK: - 消息操作扩展

extension ChatHistoryService {
    // MARK: - 保存消息

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
        let context = self.getContext()
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == conversationId }
        )

        guard let fetchedConversation = try? context.fetch(descriptor).first else {
            AppLogger.core.error("\(Self.t)❌ 无法找到对话")
            return nil
        }

        // 去重检查：如果相同 ID 的消息已存在，执行更新而非插入
        let existingDescriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { $0.id == message.id }
        )

        if let existingEntity = try? context.fetch(existingDescriptor).first {
            AppLogger.core.warning("\(Self.t)⚠️ 检测到相同 ID 的消息已存在: \(message.id)")

            existingEntity.apply(from: message, in: context)
            existingEntity.conversation = fetchedConversation
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
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { $0.id == message.id }
        )

        guard let entity = try? context.fetch(descriptor).first else {
            return nil
        }

        guard entity.conversation?.id == conversationId else {
            return nil
        }

        entity.apply(from: message, in: context)
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

    // MARK: - 加载消息

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

    /// 按工具调用 ID 查询工具输出消息。
    /// 仅用于消息详情按需展开，不参与主时间线分页。
    func loadToolOutputMessages(
        forConversationId conversationId: UUID,
        toolCallIDs: [String]
    ) async -> [ChatMessage] {
        let normalizedIDs = Array(Set(toolCallIDs.filter { !$0.isEmpty }))
        guard !normalizedIDs.isEmpty else { return [] }

        let context = self.getContext()
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId && msg.toolCallID != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let fetched = try? context.fetch(descriptor) else {
            return []
        }

        let toolCallIDSet = Set(normalizedIDs)
        let messages = fetched.compactMap { entity -> ChatMessage? in
            guard let toolCallID = entity.toolCallID,
                  toolCallIDSet.contains(toolCallID) else { return nil }
            return entity.toChatMessage()
        }

        return messages
    }

    /// 获取会话消息总数
    /// - Parameter conversationId: 对话 ID
    /// - Returns: 消息数量
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        let context = self.getContext()

        // 直接查询 ChatMessageEntity 表计数，与 loadMessagesPage 使用相同的查询方式
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate<ChatMessageEntity> { msg in
                msg.conversation?.id == conversationId
            }
        )

        guard let entities = try? context.fetch(descriptor) else {
            return 0
        }

        // 统一可见性规则：仅统计应在聊天列表中展示的消息数量，
        // 与分页加载 `loadMessagesPage` 使用相同的过滤条件（shouldDisplayInChatList）。
        let visibleCount = entities
            .compactMap { $0.toChatMessage() }
            .filter { $0.shouldDisplayInChatList() }
            .count

        return visibleCount
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

    // MARK: - 图片关系管理

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
            let descriptor = FetchDescriptor<ImageAttachmentEntity>(
                predicate: #Predicate<ImageAttachmentEntity> { $0.id == attachment.id }
            )
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
    private func cleanupOrphanedImages(in context: ModelContext) {
        let descriptor = FetchDescriptor<ImageAttachmentEntity>()
        guard let allImages = try? context.fetch(descriptor) else { return }

        for image in allImages {
            if image.messages == nil || image.messages!.isEmpty {
                context.delete(image)
            }
        }
    }
}
