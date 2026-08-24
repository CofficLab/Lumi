import Foundation
import os
import ProviderMessage
import SuperLogKit
import SwiftData

/// Message storage service using SwiftData
///
/// Manages message persistence with SQLite database in plugin directory.
/// Thread-safe via an internal `NSLock`: each method creates its own
/// `ModelContext(container)` and serializes the context's create/read/update
/// through the lock to avoid concurrent `save` conflicts.
/// 复刻自旧版 `MessageManagerPlugin/Sources/Service/MessageStore.swift`，
/// 模型从 `LumiChatMessage` 换成新版 `ProviderMessage.Message`。
public final class MessageStore: SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message.store")

    // MARK: - Properties

    private let container: ModelContainer
    private let lock = NSLock()

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        self.container = try Self.makeContainer(databaseRootURL: databaseRootURL)
    }

    /// Runs `body` while holding the store lock, making each operation atomic
    /// with respect to other callers.
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    static func makeContainer(databaseRootURL: URL) throws -> ModelContainer {
        let schema = Schema([MessageModel.self])
        // `databaseRootURL` 已是插件专属数据目录（由调用方通过
        // `StorageProviding.pluginDataDirectory(for:)` 传入），直接作为数据库目录，
        // 不再追加插件名子目录（对齐 ConversationStore 的写法）。
        let dbDir = databaseRootURL
        let dbURL = dbDir.appendingPathComponent("messages.sqlite")
        let fileManager = FileManager.default

        do {
            quarantineFileIfItBlocksDirectory(at: dbDir)
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
        } catch {
            throw MessageStoreError.initializationFailed("消息数据库目录: \(error.localizedDescription)")
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
    func insertMessage(_ message: Message) throws -> MessageModel {
        try locked {
            let context = ModelContext(container)
            let model = MessageModel.from(message: message)
            context.insert(model)
            try context.save()
            return model
        }
    }

    // MARK: - Read

    /// 返回某会话全部消息（按 createdAt 升序）。
    func fetchMessages(conversationId: UUID) -> [Message] {
        locked {
            let context = ModelContext(container)
            let conversationIdString = conversationId.uuidString

            let descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> { $0.conversationId == conversationIdString },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )

            do {
                let models = try context.fetch(descriptor)
                let messages = models.compactMap { $0.toMessage() }
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
    }

    /// Fetch a single page of messages for a conversation.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of messages to return.
    ///   - beforeMessageID: If provided, returns the page immediately before this message.
    ///     When `nil`, returns the latest page.
    ///   - includesToolMessages: When `false`, tool-result messages (role == "tool") are
    ///     excluded by the SQL predicate and do not count toward `limit`. These messages
    ///     carry the payloads sent to the LLM and are usually not needed by the UI.
    func fetchMessagePage(
        conversationId: UUID,
        limit: Int,
        beforeMessageID: UUID? = nil,
        includesToolMessages: Bool = true
    ) -> [Message] {
        guard limit > 0 else { return [] }

        return locked {
            let context = ModelContext(container)
            let conversationIdString = conversationId.uuidString

            if let beforeMessageID {
                guard let pivot = Self.fetchMessageLocked(id: beforeMessageID, in: context) else { return [] }
                let pivotCreatedAt = pivot.createdAt.timeIntervalSince1970
                let pivotID = beforeMessageID.uuidString

                var descriptor = FetchDescriptor<MessageModel>(
                    predicate: #Predicate<MessageModel> {
                        $0.conversationId == conversationIdString &&
                        (
                            $0.createdAt < pivotCreatedAt ||
                            ($0.createdAt == pivotCreatedAt && $0.id < pivotID)
                        ) &&
                        (includesToolMessages || $0.role != "tool")
                    },
                    sortBy: [
                        SortDescriptor(\.createdAt, order: .reverse),
                        SortDescriptor(\.id, order: .reverse),
                    ]
                )
                descriptor.fetchLimit = limit

                do {
                    let models = try context.fetch(descriptor)
                    return models.reversed().compactMap { $0.toMessage() }
                } catch {
                    Self.logger.error("\(Self.t)查询消息分页失败：\(error.localizedDescription)")
                    return []
                }
            }

            var descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> {
                    $0.conversationId == conversationIdString &&
                    (includesToolMessages || $0.role != "tool")
                },
                sortBy: [
                    SortDescriptor(\.createdAt, order: .reverse),
                    SortDescriptor(\.id, order: .reverse),
                ]
            )
            descriptor.fetchLimit = limit

            do {
                let models = try context.fetch(descriptor)
                return models.reversed().compactMap { $0.toMessage() }
            } catch {
                Self.logger.error("\(Self.t)查询消息分页失败：\(error.localizedDescription)")
                return []
            }
        }
    }

    /// Whether there are earlier messages before the given message.
    ///
    /// Delegates to `fetchMessagePage`, which already serializes through the lock.
    func hasEarlierMessages(
        conversationId: UUID,
        beforeMessageID: UUID? = nil,
        includesToolMessages: Bool = true
    ) -> Bool {
        let pageSize = 10

        if beforeMessageID != nil {
            return !fetchMessagePage(
                conversationId: conversationId,
                limit: 1,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages
            ).isEmpty
        }

        return fetchMessagePage(
            conversationId: conversationId,
            limit: pageSize + 1,
            beforeMessageID: nil,
            includesToolMessages: includesToolMessages
        ).count > pageSize
    }

    /// Count messages for a conversation without materializing message bodies.
    func messageCount(conversationId: UUID) -> Int {
        locked {
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
    }

    /// 返回指定日期（含）以来、按本地自然日聚合的消息数。
    func dailyMessageCounts(since: Date) -> [Date: Int] {
        locked {
            let context = ModelContext(container)
            let timestamp = since.timeIntervalSince1970
            let descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> { $0.createdAt >= timestamp }
            )
            guard let models = try? context.fetch(descriptor) else { return [:] }
            let calendar = Calendar.current
            return models.reduce(into: [:]) { counts, model in
                let day = calendar.startOfDay(for: Date(timeIntervalSince1970: model.createdAt))
                counts[day, default: 0] += 1
            }
        }
    }

    /// 返回指定日期（含）以来、按本地自然日聚合的输入与输出 token 总数。
    func dailyTokenCounts(since: Date) -> [Date: Int] {
        locked {
            let context = ModelContext(container)
            let timestamp = since.timeIntervalSince1970
            let descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> { $0.createdAt >= timestamp }
            )
            guard let models = try? context.fetch(descriptor) else { return [:] }
            let calendar = Calendar.current
            return models.reduce(into: [:]) { counts, model in
                let tokens = (model.inputTokenCount ?? 0) + (model.outputTokenCount ?? 0)
                guard tokens > 0 else { return }
                let day = calendar.startOfDay(for: Date(timeIntervalSince1970: model.createdAt))
                counts[day, default: 0] += tokens
            }
        }
    }

    /// 一次性返回所有「在磁盘上至少有一条消息」的 conversationId 字符串集合。
    ///
    /// 用于批量判定空对话，避免对每个 conversation 单独 `messageCount`（N 次 SQLite
    /// 往返）。单次 fetch 后在内存去重。
    func conversationIDsHavingMessages() -> Set<String> {
        locked {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<MessageModel>()
            descriptor.propertiesToFetch = [\.conversationId]
            guard let models = try? context.fetch(descriptor) else { return [] }
            return Set(models.map(\.conversationId))
        }
    }

    /// Fetch a single message by ID
    func fetchMessage(id: UUID) -> Message? {
        locked {
            let context = ModelContext(container)
            return Self.fetchMessageLocked(id: id, in: context)
        }
    }

    // MARK: - Update

    /// Update message content
    func updateMessage(id: UUID, content: String) -> Bool {
        locked {
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
    }

    /// Update the tool calls (incl. nested tool results) of a message.
    ///
    /// `MessageToolCall` (and its nested `MessageToolResult.imageAttachments`) is
    /// `Codable`, so encoding the rebuilt `toolCalls` array preserves tool-result
    /// images across restarts — `updateToolCallResult` previously only mutated
    /// the in-memory cache.
    func updateToolCalls(id: UUID, toolCalls: [MessageToolCall]) -> Bool {
        locked {
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
    }

    // MARK: - Delete

    /// Delete a message by ID
    func deleteMessage(id: UUID) -> Bool {
        locked {
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
    }

    /// Delete all messages for a conversation
    func deleteAllMessages(conversationId: UUID) -> Bool {
        locked {
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
    }

    // MARK: - Private

    /// Fetches a single message by ID on an already-acquired `context`.
    /// Callers must already hold `lock` (used by `fetchMessage` and `fetchMessagePage`).
    private static func fetchMessageLocked(id: UUID, in context: ModelContext) -> Message? {
        let idString = id.uuidString

        let descriptor = FetchDescriptor<MessageModel>(
            predicate: #Predicate<MessageModel> { $0.id == idString }
        )

        return try? context.fetch(descriptor).first?.toMessage()
    }

    private func save(_ context: ModelContext, operation: StaticString) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            Self.logger.error("\(Self.t)\(operation)失败：\(error.localizedDescription)")
            return false
        }
    }

    private static func messageMetrics(_ messages: [Message]) -> (
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
}

// MARK: - Database Root URL

public extension MessageStore {
    /// Default database root URL (temporary directory)
    static var defaultDatabaseRootURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Lumi/MessageManager")
    }
}
