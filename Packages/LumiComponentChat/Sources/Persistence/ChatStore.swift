import Foundation
import LumiComponentMessage
import SwiftData

@MainActor
struct ChatStore {
    struct Snapshot {
        var conversations: [LumiConversationSummary]
        var messagesByConversationID: [UUID: [LumiChatMessage]]
        var selectedConversationID: UUID?
        var selectedProviderID: String?
        var selectedModel: String?
        var routingMode: LumiModelRoutingMode

        static let empty = Snapshot(
            conversations: [],
            messagesByConversationID: [:],
            selectedConversationID: nil,
            selectedProviderID: nil,
            selectedModel: nil,
            routingMode: .manual
        )
    }

    /// `ModelContainer` is `Sendable` on Apple platforms and safe to share across
    /// actors. Marking it `nonisolated` lets background queries build their own
    /// throwaway `ModelContext` off the main actor (see `dailyMessageCounts(since:)`).
    nonisolated private let container: ModelContainer
    private let context: ModelContext

    /// Accessible to callers that need to run read-only history queries on a
    /// background context (off the main actor). Matches the per-call context
    /// pattern used by `TaskStateManager` / `CacheManager`.
    nonisolated var sharedContainer: ModelContainer { container }
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    init(configuration: Configuration, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: configuration.databaseDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let schema = Schema([
            Conversation.self,
            ChatMessageEntity.self,
            ImageAttachmentEntity.self,
            ToolCallEntity.self,
            MessageMetricsEntity.self,
            ChatStateEntity.self,
        ])
        let storeURL = configuration.databaseDirectory
            .appendingPathComponent(configuration.databaseFileName, isDirectory: false)

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        // 数据库打开失败（磁盘满、文件损坏、schema 迁移失败、权限问题）属于不可恢复的
        // 启动错误，直接抛出由 WindowMain 走 CrashedView，而不是 fatalError 闪退。
        self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])

        self.context = ModelContext(container)
    }

    func load() throws -> Snapshot {
        let conversationDescriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let conversationEntities = try context.fetch(conversationDescriptor)
        let conversations = conversationEntities.map(conversationSummary(from:))

        let messageDescriptor = FetchDescriptor<ChatMessageEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let messageEntities = try context.fetch(messageDescriptor)
        var messagesByConversationID: [UUID: [LumiChatMessage]] = [:]
        for entity in messageEntities {
            messagesByConversationID[entity.conversationId, default: []].append(message(from: entity))
        }

        let state = try currentState(createIfNeeded: false)
        let selectedID = state?.selectedConversationID.flatMap { id in
            conversations.contains(where: { $0.id == id }) ? id : conversations.first?.id
        } ?? conversations.first?.id

        return Snapshot(
            conversations: conversations,
            messagesByConversationID: messagesByConversationID,
            selectedConversationID: selectedID,
            selectedProviderID: state?.selectedProviderID,
            selectedModel: state?.selectedModel,
            routingMode: state?.routingMode.flatMap(LumiModelRoutingMode.init(rawValue:)) ?? .manual
        )
    }

    // MARK: - Full Save (fallback, only for bulk sync)

    func save(_ snapshot: Snapshot) {
        do {
            try upsertConversations(snapshot.conversations)
            try upsertMessages(snapshot.messagesByConversationID)
            try saveState(snapshot)
        } catch {
            assertionFailure("LumiChatKit failed to save SwiftData store: \(error)")
        }
    }

    // MARK: - Incremental Saves

    /// 增量保存单个对话（新建或更新）。
    /// 只按 ID fetch 该条记录，不做全量扫描。
    func upsertConversation(_ conversation: LumiConversationSummary) {
        do {
            let entity = try fetchConversation(id: conversation.id) ?? Conversation(
                id: conversation.id,
                title: conversation.title
            )
            if entity.modelContext == nil {
                context.insert(entity)
            }
            applyConversation(conversation, to: entity)
            try context.save()
        } catch {
            assertionFailure("LumiChatKit failed to upsert conversation: \(error)")
        }
    }

    /// 增量保存单条消息。只按 ID fetch 该条记录。
    func upsertMessage(_ message: LumiChatMessage) {
        do {
            let entity = try fetchMessage(id: message.id) ?? ChatMessageEntity(
                id: message.id,
                conversationId: message.conversationID,
                role: message.role.rawValue,
                content: message.content,
                reasoningContent: message.reasoningContent
            )
            if entity.modelContext == nil {
                context.insert(entity)
            }
            applyMessage(message, to: entity)
            try context.save()
        } catch {
            assertionFailure("LumiChatKit failed to upsert message: \(error)")
        }
    }

    /// 增量更新状态（selectedConversationID、provider、model、routingMode）。
    func saveState(_ snapshot: Snapshot) throws {
        let state = try currentState(createIfNeeded: true) ?? ChatStateEntity()
        state.selectedConversationID = snapshot.selectedConversationID
        state.selectedProviderID = snapshot.selectedProviderID
        state.selectedModel = snapshot.selectedModel
        state.routingMode = snapshot.routingMode.rawValue
        if state.modelContext == nil {
            context.insert(state)
        }
        try context.save()
    }

    /// 只保存状态部分（不含对话和消息），用于 selectConversation 等轻量操作。
    func saveStateOnly(
        selectedConversationID: UUID?,
        selectedProviderID: String?,
        selectedModel: String?,
        routingMode: LumiModelRoutingMode
    ) {
        do {
            let state = try currentState(createIfNeeded: true) ?? ChatStateEntity()
            state.selectedConversationID = selectedConversationID
            state.selectedProviderID = selectedProviderID
            state.selectedModel = selectedModel
            state.routingMode = routingMode.rawValue
            if state.modelContext == nil {
                context.insert(state)
            }
            try context.save()
        } catch {
            assertionFailure("LumiChatKit failed to save state: \(error)")
        }
    }

    /// 删除单个对话及其所有消息。
    func deleteConversationAndMessages(conversationID: UUID) {
        do {
            // 删除该对话的所有消息
            let messageDescriptor = FetchDescriptor<ChatMessageEntity>(
                predicate: #Predicate { $0.conversationId == conversationID }
            )
            for entity in try context.fetch(messageDescriptor) {
                context.delete(entity)
            }

            // 删除对话本身
            if let conversation = try fetchConversation(id: conversationID) {
                context.delete(conversation)
            }

            try context.save()
        } catch {
            assertionFailure("LumiChatKit failed to delete conversation: \(error)")
        }
    }

    /// 删除单条消息。
    func deleteMessage(id: UUID) {
        do {
            if let entity = try fetchMessage(id: id) {
                context.delete(entity)
                try context.save()
            }
        } catch {
            assertionFailure("LumiChatKit failed to delete message: \(error)")
        }
    }

    // MARK: - Full Upsert (internal, used by save() fallback)

    private func upsertConversations(_ conversations: [LumiConversationSummary]) throws {
        let existingEntities = try context.fetch(FetchDescriptor<Conversation>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.id, $0) })
        let incomingIDs = Set(conversations.map(\.id))

        for entity in existingEntities where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }

        for conversation in conversations {
            let entity = existingByID[conversation.id] ?? Conversation(
                id: conversation.id,
                title: conversation.title
            )
            if entity.modelContext == nil {
                context.insert(entity)
            }
            applyConversation(conversation, to: entity)
        }
    }

    private func upsertMessages(_ messagesByConversationID: [UUID: [LumiChatMessage]]) throws {
        let existingEntities = try context.fetch(FetchDescriptor<ChatMessageEntity>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingEntities.map { ($0.id, $0) })
        let incomingMessages = messagesByConversationID.values.flatMap { $0 }
        let incomingIDs = Set(incomingMessages.map(\.id))

        for entity in existingEntities where !incomingIDs.contains(entity.id) {
            context.delete(entity)
        }

        for message in incomingMessages {
            let entity = existingByID[message.id] ?? ChatMessageEntity(
                id: message.id,
                conversationId: message.conversationID,
                role: message.role.rawValue,
                content: message.content
            )
            if entity.modelContext == nil {
                context.insert(entity)
            }
            applyMessage(message, to: entity)
        }
    }

    // MARK: - Single-Record Fetches

    private func fetchConversation(id: UUID) throws -> Conversation? {
        var descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchMessage(id: UUID) throws -> ChatMessageEntity? {
        var descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Field Application

    private func applyConversation(_ conversation: LumiConversationSummary, to entity: Conversation) {
        entity.title = conversation.title
        entity.preview = conversation.preview
        entity.createdAt = conversation.createdAt
        entity.updatedAt = conversation.updatedAt
        entity.chatMode = conversation.automationLevel?.rawValue
        entity.verbosity = conversation.verbosity?.rawValue
        entity.languagePreference = conversation.language?.rawValue
        entity.providerId = conversation.providerID
        entity.model = conversation.modelName
        entity.projectId = conversation.projectPath
    }

    private func applyMessage(_ message: LumiChatMessage, to entity: ChatMessageEntity) {
        entity.conversationId = message.conversationID
        entity.role = message.role.rawValue
        entity.content = message.content
        entity.timestamp = message.createdAt
        entity.providerId = message.providerID
        entity.modelName = message.modelName
        entity.isError = message.isError
        entity.rawErrorDetail = message.rawErrorDetail
        entity.renderKind = message.renderKind
        entity.metadataJSON = encode(message.metadata)
        entity.toolCallsJSON = encode(message.toolCalls)
        entity.toolCallID = message.toolCallID
        entity.reasoningContent = message.reasoningContent
    }

    private func currentState(createIfNeeded: Bool) throws -> ChatStateEntity? {
        var descriptor = FetchDescriptor<ChatStateEntity>(
            predicate: #Predicate { $0.id == "default" }
        )
        descriptor.fetchLimit = 1
        if let state = try context.fetch(descriptor).first {
            return state
        }
        guard createIfNeeded else {
            return nil
        }
        let state = ChatStateEntity()
        context.insert(state)
        return state
    }

    private func conversationSummary(from entity: Conversation) -> LumiConversationSummary {
        LumiConversationSummary(
            id: entity.id,
            title: entity.title,
            preview: entity.preview,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            verbosity: entity.verbosity.flatMap(LumiResponseVerbosity.init(rawValue:)),
            language: entity.languagePreference.flatMap(LumiConversationLanguage.init(rawValue:)),
            automationLevel: entity.chatMode.flatMap(LumiAutomationLevel.init(rawValue:)),
            providerID: entity.providerId,
            modelName: entity.model,
            projectPath: entity.projectId
        )
    }

    private func message(from entity: ChatMessageEntity) -> LumiChatMessage {
        LumiChatMessage(
            id: entity.id,
            conversationID: entity.conversationId,
            role: LumiChatMessageRole(rawValue: entity.role) ?? .assistant,
            content: entity.content,
            createdAt: entity.timestamp,
            providerID: entity.providerId,
            modelName: entity.modelName,
            isError: entity.isError,
            rawErrorDetail: entity.rawErrorDetail,
            renderKind: entity.renderKind,
            metadata: decode([String: String].self, from: entity.metadataJSON) ?? [:],
            toolCalls: decode([LumiToolCall].self, from: entity.toolCallsJSON),
            toolCallID: entity.toolCallID,
            reasoningContent: entity.reasoningContent
        )
    }

    private func encode<T: Encodable>(_ value: T?) -> String? {
        guard let value,
              let data = try? jsonEncoder.encode(value)
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func decode<T: Decodable>(_ type: T.Type, from string: String?) -> T? {
        guard let string,
              let data = string.data(using: .utf8)
        else {
            return nil
        }
        return try? jsonDecoder.decode(type, from: data)
    }

    private static func quarantineStoreFiles(baseURL: URL, fileManager: FileManager) {
        let suffix = "corrupt-\(UUID().uuidString)"
        for url in [
            baseURL,
            URL(fileURLWithPath: baseURL.path + "-wal"),
            URL(fileURLWithPath: baseURL.path + "-shm"),
        ] where fileManager.fileExists(atPath: url.path) {
            let quarantinedURL = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent).\(suffix)")
            try? fileManager.moveItem(at: url, to: quarantinedURL)
        }
    }

    func historyMessageCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<ChatMessageEntity>())) ?? 0
    }

    func historyConversationCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<Conversation>())) ?? 0
    }

    /// Lightweight, background-safe aggregation of message counts per day for all
    /// days on or after `since`.
    ///
    /// This is a `static` taking the `Sendable` container, so it can be called from
    /// any `nonisolated` context (off the main actor) — see
    /// `ChatService.fetchDailyMessageCounts(since:)`. It builds a throwaway
    /// `ModelContext` (the established pattern in `TaskStateManager`/`CacheManager`)
    /// and performs a single windowed fetch that reads **only** `timestamp` — no
    /// `content`, no thinking previews, no token lookups, no full-table helper
    /// scans. This keeps the UI thread free even with thousands of messages.
    nonisolated static func dailyMessageCounts(
        container: ModelContainer,
        since: Date
    ) -> [Date: Int] {
        let backgroundContext = ModelContext(container)
        let calendar = Calendar.current

        let predicate = #Predicate<ChatMessageEntity> { $0.timestamp >= since }
        let descriptor = FetchDescriptor<ChatMessageEntity>(predicate: predicate)

        guard let messages = try? backgroundContext.fetch(descriptor) else {
            return [:]
        }

        var counts: [Date: Int] = [:]
        for message in messages {
            let day = calendar.startOfDay(for: message.timestamp)
            counts[day, default: 0] += 1
        }
        return counts
    }

    nonisolated static func dailyTokenCounts(
        container: ModelContainer,
        since: Date
    ) -> [Date: Int] {
        let bgCtx = ModelContext(container)
        let cal = Calendar.current
        let msgPred = #Predicate<ChatMessageEntity> { $0.timestamp >= since }
        let msgDesc = FetchDescriptor<ChatMessageEntity>(predicate: msgPred)
        guard let msgs = try? bgCtx.fetch(msgDesc) else { return [:] }
        let tsByID = Dictionary(uniqueKeysWithValues: msgs.map { ($0.id, $0.timestamp) })
        guard let metrics = try? bgCtx.fetch(FetchDescriptor<MessageMetricsEntity>()) else { return [:] }
        var result: [Date: Int] = [:]
        for m in metrics {
            guard let total = m.totalTokens,
                  let ts = tsByID[m.messageId],
                  ts >= since else { continue }
            let day = cal.startOfDay(for: ts)
            result[day, default: 0] += total
        }
        return result
    }

    func historyMessagePage(limit: Int, offset: Int) -> [HistoryMessageRow] {
        let safeLimit = max(limit, 1)
        let safeOffset = max(offset, 0)

        do {
            let titlesByConversationID = conversationTitlesByID()
            let tokenCountsByMessageID = messageTokenCountsByID()
            let thinkingMetricsByMessageID = messageThinkingMetricsByMessageID()

            var descriptor = FetchDescriptor<ChatMessageEntity>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchOffset = safeOffset
            descriptor.fetchLimit = safeLimit

            return try context.fetch(descriptor).map { entity in
                let preview = entity.content
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let thinking = thinkingMetricsByMessageID[entity.id]
                let thinkingPreview = thinking?.content?
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let hasThinking = thinking?.hasThinking ?? false

                return HistoryMessageRow(
                    id: entity.id,
                    conversationId: entity.conversationId,
                    conversationTitle: titlesByConversationID[entity.conversationId] ?? "-",
                    role: entity.role,
                    model: entity.modelName ?? "-",
                    tokens: tokenCountsByMessageID[entity.id] ?? 0,
                    timestamp: entity.timestamp,
                    contentPreview: preview,
                    thinkingContentPreview: thinkingPreview,
                    hasThinking: hasThinking,
                    thinkingDuration: thinking?.duration
                )
            }
        } catch {
            return []
        }
    }

    func historyConversationPage(limit: Int, offset: Int) -> [HistoryConversationRow] {
        let safeLimit = max(limit, 1)
        let safeOffset = max(offset, 0)

        do {
            var descriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchOffset = safeOffset
            descriptor.fetchLimit = safeLimit

            let conversations = try context.fetch(descriptor)
            let messageCounts = messageCountsByConversationID(for: conversations.map(\.id))

            return conversations.map { conversation in
                HistoryConversationRow(
                    id: conversation.id,
                    title: conversation.title.isEmpty ? "Untitled" : conversation.title,
                    projectId: conversation.projectId ?? "-",
                    createdAt: conversation.createdAt,
                    updatedAt: conversation.updatedAt,
                    messageCount: messageCounts[conversation.id] ?? 0,
                    providerId: conversation.providerId,
                    model: conversation.model,
                    chatMode: conversation.chatMode
                )
            }
        } catch {
            return []
        }
    }

    private func conversationTitlesByID() -> [UUID: String] {
        guard let conversations = try? context.fetch(FetchDescriptor<Conversation>()) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: conversations.map { conversation in
            let title = conversation.title.isEmpty ? "Untitled" : conversation.title
            return (conversation.id, title)
        })
    }

    private func messageTokenCountsByID() -> [UUID: Int] {
        guard let metrics = try? context.fetch(FetchDescriptor<MessageMetricsEntity>()) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: metrics.compactMap { metric in
            guard let totalTokens = metric.totalTokens else { return nil }
            return (metric.messageId, totalTokens)
        })
    }

    private struct MessageThinkingMetrics {
        let hasThinking: Bool
        let content: String?
        let duration: Double?
    }

    private func messageThinkingMetricsByMessageID() -> [UUID: MessageThinkingMetrics] {
        var result: [UUID: MessageThinkingMetrics] = [:]

        if let messageMetrics = try? context.fetch(FetchDescriptor<MessageMetricsEntity>()),
           let messageEntities = try? context.fetch(FetchDescriptor<ChatMessageEntity>()) {
            let thinkingContentByMessageID = Dictionary(
                uniqueKeysWithValues: messageMetrics.compactMap { metric -> (UUID, MessageThinkingMetrics)? in
                    guard metric.hasThinking else { return nil }
                    return (
                        metric.messageId,
                        MessageThinkingMetrics(
                            hasThinking: true,
                            content: metric.thinkingContent,
                            duration: metric.thinkingDuration
                        )
                    )
                }
            )

            for entity in messageEntities {
                if let metrics = thinkingContentByMessageID[entity.id] {
                    result[entity.id] = metrics
                } else if let reasoning = entity.reasoningContent, !reasoning.isEmpty {
                    result[entity.id] = MessageThinkingMetrics(
                        hasThinking: true,
                        content: reasoning,
                        duration: nil
                    )
                }
            }
        }

        return result
    }

    private func messageCountsByConversationID(for conversationIDs: [UUID]) -> [UUID: Int] {
        guard !conversationIDs.isEmpty else { return [:] }

        var counts: [UUID: Int] = [:]
        for conversationID in conversationIDs {
            let id = conversationID
            var descriptor = FetchDescriptor<ChatMessageEntity>(
                predicate: #Predicate { $0.conversationId == id }
            )
            counts[conversationID] = (try? context.fetchCount(descriptor)) ?? 0
        }
        return counts
    }
}
