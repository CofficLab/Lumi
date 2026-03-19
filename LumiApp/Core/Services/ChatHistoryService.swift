import Foundation
import MagicKit
import SwiftData

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

/// 模型性能统计数据
struct ModelPerformanceStats {
    let providerId: String
    let modelName: String
    var sampleCount: Int = 0
    var totalLatency: Double = 0
    var totalTTFT: Double = 0
    var ttftCount: Int = 0
    var totalInputTokens: Int = 0
    var inputTokenCount: Int = 0
    var totalOutputTokens: Int = 0
    var outputTokenCount: Int = 0
    
    var avgLatency: Double {
        sampleCount > 0 ? totalLatency / Double(sampleCount) : 0
    }
    
    var avgTTFT: Double {
        ttftCount > 0 ? totalTTFT / Double(ttftCount) : 0
    }
    
    var avgInputTokens: Int {
        inputTokenCount > 0 ? totalInputTokens / inputTokenCount : 0
    }
    
    var avgOutputTokens: Int {
        outputTokenCount > 0 ? totalOutputTokens / outputTokenCount : 0
    }
}

/// 聊天历史服务 - 使用 SwiftData 存储对话
final class ChatHistoryService: SuperLog, @unchecked Sendable {
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let llmService: LLMService
    private let storageQueue = DispatchQueue(label: "com.coffic.lumi.chat-history.storage", qos: .utility)

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
            AppLogger.core.error("\(Self.t)❌ 保存对话失败：\(error.localizedDescription)")
        }
    }

    private func notifyConversationChanged(type: ConversationChangeType, conversationId: UUID) {
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
            AppLogger.core.error("\(Self.t)❌ 生成标题失败：\(error.localizedDescription)")
            // 降级：使用消息的前 20 个字符作为标题
            return String(trimmedMessage.prefix(20))
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
            AppLogger.core.error("\(Self.t)❌ 无法在当前上下文中找到对话")
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
                AppLogger.core.info("\(Self.t)💾 [\(conversation.id)] 消息已保存：\(message.content.max(10)), 指标: [\(metrics)], 思考过程: \(hasThinking)")
            }
            // 返回保存后的消息
            guard let savedMessage = messageEntity.toChatMessage() else {
                AppLogger.core.error("\(Self.t)❌ 消息转换失败")
                return nil
            }
            NotificationCenter.postMessageSaved(message: savedMessage, conversationId: conversation.id)
            return savedMessage
        } catch {
            AppLogger.core.error("\(Self.t)❌ 保存消息失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 后台队列保存消息，避免阻塞主线程
    /// - Parameters:
    ///   - message: 要保存的消息
    ///   - conversationId: 对话 ID
    /// - Returns: 保存后的消息
    func saveMessageAsync(_ message: ChatMessage, toConversationId conversationId: UUID) async -> ChatMessage? {
        await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                // 在后台队列中使用独立 context，避免与主线程 context 争用
                let context = ModelContext(self.modelContainer)
                let descriptor = FetchDescriptor<Conversation>(
                    predicate: #Predicate { $0.id == conversationId }
                )

                guard let fetchedConversation = try? context.fetch(descriptor).first else {
                    continuation.resume(returning: nil)
                    return
                }

                let messageEntity = ChatMessageEntity.fromChatMessage(message)
                messageEntity.conversation = fetchedConversation
                fetchedConversation.updatedAt = Date()
                context.insert(messageEntity)

                do {
                    try context.save()
                    // 发送消息已保存事件
                    if let savedMessage = messageEntity.toChatMessage() {
                        NotificationCenter.postMessageSaved(message: savedMessage, conversationId: fetchedConversation.id)
                    }
                    continuation.resume(returning: messageEntity.toChatMessage())
                } catch {
                    AppLogger.core.error("\(Self.t)❌ 异步保存消息失败：\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 后台加载对话消息，避免阻塞主线程
    /// - Parameter conversationId: 对话 ID
    /// - Returns: 消息列表；若会话不存在返回 nil
    func loadMessagesAsync(forConversationId conversationId: UUID) async -> [ChatMessage]? {
        await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let context = ModelContext(self.modelContainer)
                let descriptor = FetchDescriptor<Conversation>(
                    predicate: #Predicate { $0.id == conversationId }
                )

                guard let fetchedConversation = try? context.fetch(descriptor).first else {
                    continuation.resume(returning: nil)
                    return
                }

                let messageEntities = fetchedConversation.messages.sorted { $0.timestamp < $1.timestamp }
                let messages = messageEntities.compactMap { $0.toChatMessage() }
                continuation.resume(returning: messages)
            }
        }
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
        await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: ([], false))
                    return
                }

                let context = ModelContext(self.modelContainer)

                guard limit > 0 else {
                    continuation.resume(returning: ([], false))
                    return
                }

                // 下沉“是否展示”的过滤逻辑：此 API 只返回应该展示的消息，
                // 并在分页时自动跳过被过滤的消息，避免 UI 端再做判断和跳页。
                var cursor = beforeTimestamp
                var collected: [ChatMessage] = []
                var hasMoreVisible = false

                // 批次大小：尽量减少 fetch 次数，但也避免一次拉太多
                let batchSize = max(limit * 3, limit + 10)
                // 安全阈值：避免极端情况下长时间循环（例如大量连续 tool output 被过滤）
                let maxBatches = 20
                // 记录当前页中“最旧”的一条可见消息时间戳，用于作为下一页游标
                var oldestVisibleTimestamp: Date?

                batchLoop: for _ in 0..<maxBatches {
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
                    // 如果这一批有可展示消息，则游标设为当前已收集的“最旧”可展示消息；
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

                continuation.resume(returning: (messages, hasMore))
            }
        }
    }

    /// 按工具调用 ID 查询工具输出消息。
    /// 仅用于消息详情按需展开，不参与主时间线分页。
    func loadToolOutputMessages(
        forConversationId conversationId: UUID,
        toolCallIDs: [String]
    ) async -> [ChatMessage] {
        let normalizedIDs = Array(Set(toolCallIDs.filter { !$0.isEmpty }))
        guard !normalizedIDs.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                let context = ModelContext(self.modelContainer)
                let descriptor = FetchDescriptor<ChatMessageEntity>(
                    predicate: #Predicate<ChatMessageEntity> { msg in
                        msg.conversation?.id == conversationId && msg.toolCallID != nil
                    },
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )

                guard let fetched = try? context.fetch(descriptor) else {
                    continuation.resume(returning: [])
                    return
                }

                let toolCallIDSet = Set(normalizedIDs)
                let messages = fetched.compactMap { entity -> ChatMessage? in
                    guard let toolCallID = entity.toolCallID,
                          toolCallIDSet.contains(toolCallID) else { return nil }
                    return entity.toChatMessage()
                }

                continuation.resume(returning: messages)
            }
        }
    }

    /// 获取会话消息总数
    /// - Parameter conversationId: 对话 ID
    /// - Returns: 消息数量
    func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await withCheckedContinuation { continuation in
            storageQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: 0)
                    return
                }

                let context = ModelContext(self.modelContainer)
                let descriptor = FetchDescriptor<Conversation>(
                    predicate: #Predicate { $0.id == conversationId }
                )

                guard let fetchedConversation = try? context.fetch(descriptor).first else {
                    continuation.resume(returning: 0)
                    return
                }

                // 统一可见性规则：仅统计应在聊天列表中展示的消息数量，
                // 与分页加载 `loadMessagesPage` 使用相同的过滤条件（shouldDisplayInChatList）。
                let visibleCount = fetchedConversation.messages
                    .compactMap { $0.toChatMessage() }
                    .filter { $0.shouldDisplayInChatList() }
                    .count

                continuation.resume(returning: visibleCount)
            }
        }
    }

    // MARK: - 加载对话

    /// 获取所有对话
    func fetchAllConversations() -> [Conversation] {
        let context = getContext()
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
        let context = getContext()

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
            AppLogger.core.error("\(Self.t)❌ 获取对话失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 获取项目相关的对话
    func fetchConversations(forProject projectId: String) -> [Conversation] {
        let context = getContext()
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.projectId == projectId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let conversations = try context.fetch(descriptor)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📄 获取到项目 \(projectId) 的 \(conversations.count) 个对话")
            }
            return conversations
        } catch {
            AppLogger.core.error("\(Self.t)❌ 获取项目对话失败：\(error.localizedDescription)")
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
            AppLogger.core.error("\(Self.t)❌ 无法在当前上下文中找到对话")
            return []
        }

        // 从关系中获取消息
        let messageEntities = fetchedConversation.messages.sorted { $0.timestamp < $1.timestamp }
        let messages = messageEntities.compactMap { $0.toChatMessage() }
        if Self.verbose {
            AppLogger.core.info("\(Self.t)📄 [\(conversation.id)] 加载到 \(messages.count) 条消息")
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
            notifyConversationChanged(type: .deleted, conversationId: conversation.id)
            NotificationCenter.postConversationDeleted(conversationId: conversation.id)
            if Self.verbose {
                AppLogger.core.info("\(Self.t)🗑️ 对话已删除：\(conversation.title)")
            }
        } catch {
            AppLogger.core.error("\(Self.t)❌ 删除对话失败：\(error.localizedDescription)")
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
            AppLogger.core.error("\(Self.t)❌ 获取消息失败")
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
    
    /// 获取每个供应商和模型的详细性能统计
    /// - Returns: 字典，键为 (providerId, modelName)，值为详细统计数据
    func getModelDetailedStats() -> [String: ModelPerformanceStats] {
        let context = getContext()
        
        // 获取所有有性能数据的消息
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.latency != nil && $0.providerId != nil && $0.modelName != nil }
        )

        guard let messageEntities = try? context.fetch(descriptor) else {
            AppLogger.core.error("\(Self.t)❌ 获取消息失败")
            return [:]
        }

        // 按 providerId 和 modelName 分组统计
        var statsDict: [String: ModelPerformanceStats] = [:]
        
        for entity in messageEntities {
            guard let providerId = entity.providerId,
                  let modelName = entity.modelName,
                  let latency = entity.latency else {
                continue
            }
            
            let key = "\(providerId)|\(modelName)"
            var stats = statsDict[key] ?? ModelPerformanceStats(
                providerId: providerId,
                modelName: modelName,
                sampleCount: 0,
                totalLatency: 0,
                totalTTFT: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0
            )
            
            stats.sampleCount += 1
            stats.totalLatency += latency
            
            if let ttft = entity.timeToFirstToken {
                stats.totalTTFT += ttft
                stats.ttftCount += 1
            }
            
            if let inputTokens = entity.inputTokens {
                stats.totalInputTokens += inputTokens
                stats.inputTokenCount += 1
            }
            
            if let outputTokens = entity.outputTokens {
                stats.totalOutputTokens += outputTokens
                stats.outputTokenCount += 1
            }
            
            statsDict[key] = stats
        }

        return statsDict
    }

    // MARK: - 工具方法

    /// 获取模型容器（用于 @Query）
    func getModelContainer() -> ModelContainer {
        return modelContainer
    }
}
