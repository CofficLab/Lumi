import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftData

/// Message storage service using SwiftData
///
/// Manages message persistence with SQLite database in plugin directory.
/// Thread-safe via Actor isolation, following `TaskStateManager` pattern.
public actor MessageStore: SuperLog {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.store")

    // MARK: - Properties

    private let container: ModelContainer

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        self.container = try Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    static func makeContainer(databaseRootURL: URL) throws -> ModelContainer {
        let schema = Schema([MessageModel.self])
        let dbDir = databaseRootURL.appendingPathComponent("MessageManagerPlugin", isDirectory: true)
        let dbURL = dbDir.appendingPathComponent("messages.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            throw MessageStoreError.initializationFailed("MessageManagerPlugin 数据库目录: \(error.localizedDescription)")
        }

        let config = ModelConfiguration(
            schema: schema,
            url: dbURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)打开消息数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        // 重建尝试
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            throw MessageStoreError.initializationFailed("MessageManagerPlugin 数据库重建失败: \(error.localizedDescription)")
        }
    }

    private static func quarantinePersistentStore(at dbURL: URL) {
        let fileManager = FileManager.default
        let storeURLs = [
            dbURL,
            URL(fileURLWithPath: dbURL.path + "-shm"),
            URL(fileURLWithPath: dbURL.path + "-wal"),
        ]

        for url in storeURLs where fileManager.fileExists(atPath: url.path) {
            quarantineFile(at: url)
        }
    }

    private static func quarantineFileIfItBlocksDirectory(at url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        quarantineFile(at: url)
    }

    private static func quarantineFile(at url: URL) {
        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".corrupt-\(Int(Date().timeIntervalSince1970))")
        do {
            try FileManager.default.moveItem(at: url, to: destination)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)隔离消息数据库文件失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Create / Insert

    /// Insert a new message
    @discardableResult
    func insertMessage(_ message: LumiChatMessage) throws -> MessageModel {
        let context = ModelContext(container)
        let model = MessageModel.from(message: message)
        context.insert(model)
        try context.save()

        if Self.verbose {
            Self.logger.info("\(Self.t)插入消息：\(message.id) to conversation \(message.conversationID)")
        }

        return model
    }

    // MARK: - Migration Import

    /// 批量导入历史消息(v4 迁移专用)
    ///
    /// 用于 v4 → v5 迁移:把 `LegacyDataProviding` 读出的 `LumiChatMessage` 批量写入
    /// v5 库,单次 `save` 保证原子性和性能(2 万条消息若逐条 save 会很慢)。按 id 去重:
    /// 已存在的消息跳过,避免重复导入。
    ///
    /// - Parameter messages: 待导入的消息列表。
    /// - Returns: 实际新增的数量(跳过已存在的)。
    @discardableResult
    func importMessages(_ messages: [LumiChatMessage]) throws -> Int {
        guard !messages.isEmpty else { return 0 }

        let context = ModelContext(container)

        // 查出已存在的 id 集合,用于去重
        let existingIDs: Set<String> = {
            let descriptor = FetchDescriptor<MessageModel>()
            let models = (try? context.fetch(descriptor)) ?? []
            return Set(models.map { $0.id })
        }()

        var inserted = 0
        for message in messages {
            let idString = message.id.uuidString
            guard !existingIDs.contains(idString) else { continue }
            context.insert(MessageModel.from(message: message))
            inserted += 1
        }

        guard inserted > 0 else { return 0 }

        do {
            try context.save()
            if Self.verbose {
                Self.logger.info("\(Self.t)迁移导入 \(inserted) 条历史消息")
            }
            return inserted
        } catch {
            Self.logger.error("\(Self.t)迁移导入消息失败：\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Read

    /// Fetch all messages for a conversation, sorted by createdAt
    func fetchMessages(conversationId: UUID) -> [LumiChatMessage] {
        let context = ModelContext(container)
        let conversationIdString = conversationId.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        do {
            let models = try context.fetch(descriptor)
            let messages = models.compactMap { $0.toLumiChatMessage() }
            if Self.verbose {
                let metrics = Self.messageMetrics(messages)
                Self.logger.info("\(Self.t)fetchMessages materialized conversation=\(conversationId.uuidString.prefix(8)) messages=\(messages.count) contentChars=\(metrics.contentChars) metadataChars=\(metrics.metadataChars) reasoningChars=\(metrics.reasoningChars) toolCallArgumentChars=\(metrics.toolCallArgumentChars)")
            }
            return messages
        } catch {
            Self.logger.error("\(Self.t)查询消息失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Fetch a single page of messages for a conversation.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of messages to return.
    ///   - beforeMessageID: If provided, returns the page immediately before this message.
    ///     When `nil`, returns the latest page.
    func fetchMessagePage(
        conversationId: UUID,
        limit: Int,
        beforeMessageID: UUID? = nil
    ) -> [LumiChatMessage] {
        guard limit > 0 else { return [] }

        let context = ModelContext(container)
        let conversationIdString = conversationId.uuidString

        if let beforeMessageID {
            guard let pivot = fetchMessage(id: beforeMessageID) else { return [] }
            let pivotCreatedAt = pivot.createdAt.timeIntervalSince1970
            let pivotID = beforeMessageID.uuidString

            var descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> {
                    $0.conversationId == conversationIdString &&
                    (
                        $0.createdAt < pivotCreatedAt ||
                        ($0.createdAt == pivotCreatedAt && $0.id < pivotID)
                    )
                },
                sortBy: [
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse),
                ]
            )
            descriptor.fetchLimit = limit

            do {
                let models = try context.fetch(descriptor)
                return models.reversed().compactMap { $0.toLumiChatMessage() }
            } catch {
                Self.logger.error("\(Self.t)查询消息分页失败：\(error.localizedDescription)")
                return []
            }
        }

        var descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString },
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.id, order: .reverse),
            ]
        )
        descriptor.fetchLimit = limit

        do {
            let models = try context.fetch(descriptor)
            return models.reversed().compactMap { $0.toLumiChatMessage() }
        } catch {
            Self.logger.error("\(Self.t)查询消息分页失败：\(error.localizedDescription)")
            return []
        }
    }

    /// Whether there are earlier messages before the given message.
    func hasEarlierMessages(conversationId: UUID, beforeMessageID: UUID? = nil) -> Bool {
        let pageSize = 10

        if let beforeMessageID {
            return !fetchMessagePage(conversationId: conversationId, limit: 1, beforeMessageID: beforeMessageID).isEmpty
        }

        return fetchMessagePage(conversationId: conversationId, limit: pageSize + 1, beforeMessageID: nil).count > pageSize
    }

    /// Count messages for a conversation without materializing message bodies.
    func messageCount(conversationId: UUID) -> Int {
        let context = ModelContext(container)
        let conversationIdString = conversationId.uuidString
        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString }
        )

        do {
            let count = try context.fetchCount(descriptor)
            if Self.verbose {
                Self.logger.info("\(Self.t)messageCount fetchCount conversation=\(conversationId.uuidString.prefix(8)) count=\(count) materializedMessages=false")
            }
            return count
        } catch {
            Self.logger.error("\(Self.t)统计消息数量失败：\(error.localizedDescription)")
            return 0
        }
    }

    /// Fetch a single message by ID
    func fetchMessage(id: UUID) -> LumiChatMessage? {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        return try? context.fetch(descriptor).first?.toLumiChatMessage()
    }

    // MARK: - Update

    /// Update message content
    func updateMessage(id: UUID, content: String) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        model.content = content
        return save(context, operation: "更新消息")
    }

    /// Update the tool calls (incl. nested tool results) of a message.
    ///
    /// `LumiToolCall` (and its nested `LumiToolResult.imageAttachments`) is `Codable`,
    /// so encoding the rebuilt `toolCalls` array preserves tool-result images across
    /// restarts — `updateToolCallResult` previously only mutated the in-memory cache.
    func updateToolCalls(id: UUID, toolCalls: [LumiToolCall]) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        let data = try? JSONEncoder().encode(toolCalls)
        model.toolCallsJson = data.flatMap { String(data: $0, encoding: .utf8) }
        return save(context, operation: "更新 toolCalls")
    }

    // MARK: - Delete

    /// Delete a message by ID
    func deleteMessage(id: UUID) -> Bool {
        let context = ModelContext(container)
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        guard let model = try? context.fetch(descriptor).first else {
            return false
        }

        context.delete(model)
        return save(context, operation: "删除消息")
    }

    /// Delete all messages for a conversation
    func deleteAllMessages(conversationId: UUID) -> Bool {
        let context = ModelContext(container)
        let conversationIdString = conversationId.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString }
        )

        do {
            let models = try context.fetch(descriptor)
            for model in models {
                context.delete(model)
            }
            try context.save()
            return true
        } catch {
            Self.logger.error("\(Self.t)删除会话消息失败：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            Self.logger.error("\(Self.t)\(operation)失败：\(error.localizedDescription)")
            return false
        }
    }

    private static func messageMetrics(_ messages: [LumiChatMessage]) -> (
        contentChars: Int,
        metadataChars: Int,
        reasoningChars: Int,
        toolCallArgumentChars: Int
    ) {
        var contentChars = 0
        var metadataChars = 0
        var reasoningChars = 0
        var toolCallArgumentChars = 0

        for message in messages {
            contentChars += message.content.count
            metadataChars += message.metadata.reduce(0) { $0 + $1.key.count + $1.value.count }
            reasoningChars += message.reasoningContent?.count ?? 0
            toolCallArgumentChars += message.toolCalls?.reduce(0) { $0 + $1.arguments.count } ?? 0
        }

        return (contentChars, metadataChars, reasoningChars, toolCallArgumentChars)
    }

    private static func tokenCounts(for model: MessageModel, decoder: JSONDecoder) -> (input: Int, output: Int) {
        let metadata: [String: String]
        if let metadataJson = model.metadataJson,
           let data = metadataJson.data(using: .utf8),
           let decoded = try? decoder.decode([String: String].self, from: data) {
            metadata = decoded
        } else {
            metadata = [:]
        }

        let inputTokens = model.inputTokenCount
            ?? metadata[LumiMessageTokenMetadata.inputKey].flatMap { Int($0) }
            ?? 0
        let outputTokens = model.outputTokenCount
            ?? metadata[LumiMessageTokenMetadata.outputKey].flatMap { Int($0) }
            ?? 0
        return (inputTokens, outputTokens)
    }

    // MARK: - Aggregate Queries

    /// 获取自指定日期以来每日的消息数量
    func fetchDailyMessageCounts(since: Date) -> [Date: Int] {
        let context = ModelContext(container)
        let sinceTimestamp = since.timeIntervalSince1970

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.createdAt >= sinceTimestamp }
        )

        guard let models = try? context.fetch(descriptor) else { return [:] }

        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        for model in models {
            let date = Date(timeIntervalSince1970: model.createdAt)
            let day = calendar.startOfDay(for: date)
            counts[day, default: 0] += 1
        }
        return counts
    }

    /// 获取自指定日期以来每日的 token 消耗总量
    func fetchDailyTokenCounts(since: Date) -> [Date: Int] {
        let context = ModelContext(container)
        let sinceTimestamp = since.timeIntervalSince1970

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.createdAt >= sinceTimestamp }
        )

        guard let models = try? context.fetch(descriptor) else { return [:] }

        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        let decoder = JSONDecoder()
        for model in models {
            let date = Date(timeIntervalSince1970: model.createdAt)
            let day = calendar.startOfDay(for: date)
            let tokenCounts = Self.tokenCounts(for: model, decoder: decoder)
            let tokens = tokenCounts.input + tokenCounts.output
            if tokens > 0 {
                counts[day, default: 0] += tokens
            }
        }
        return counts
    }

    /// 获取某一天的 token 消耗量，可按供应商和模型过滤。
    func fetchTokenUsage(on day: Date, providerID: String? = nil, modelName: String? = nil) -> MessageTokenUsage {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return MessageTokenUsage(day: startOfDay, inputTokens: 0, outputTokens: 0)
        }

        let startTimestamp = startOfDay.timeIntervalSince1970
        let endTimestamp = endOfDay.timeIntervalSince1970
        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> {
                $0.createdAt >= startTimestamp && $0.createdAt < endTimestamp
            }
        )

        guard let models = try? context.fetch(descriptor) else {
            return MessageTokenUsage(day: startOfDay, inputTokens: 0, outputTokens: 0)
        }

        let decoder = JSONDecoder()
        var inputTokens = 0
        var outputTokens = 0
        for model in models {
            if let providerID, model.providerId != providerID {
                continue
            }
            if let modelName, model.modelName != modelName {
                continue
            }

            let tokenCounts = Self.tokenCounts(for: model, decoder: decoder)
            inputTokens += tokenCounts.input
            outputTokens += tokenCounts.output
        }

        return MessageTokenUsage(day: startOfDay, inputTokens: inputTokens, outputTokens: outputTokens)
    }
}

// MARK: - Database Root URL

public extension MessageStore {
    /// Default database root URL (temporary directory)
    static var defaultDatabaseRootURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/MessageManager")
    }
}
