import Foundation
import os
import ProviderMessage
import LumiLoggingKit
import SQLite3
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
            let container = try ModelContainer(for: schema, configurations: [config])
            Self.ensureConversationLookupIndex(at: dbURL)
            return container
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)打开消息数据库失败，准备重建：\(error.localizedDescription)")
            }
            quarantinePersistentStore(at: dbURL)
        }

        // 重建尝试
        do {
            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            Self.ensureConversationLookupIndex(at: dbURL)
            return container
        } catch {
            throw MessageStoreError.initializationFailed("MessageManagerPlugin 数据库重建失败: \(error.localizedDescription)")
        }
    }

    /// 建立「按会话 + 时间倒序」取消息所需的复合索引。
    ///
    /// ## 为什么必须手工建
    ///
    /// SwiftData 的 `#Index` 宏要求 macOS 15，而本插件最低支持 macOS 14，
    /// 因此直接用 SQLite 建等效索引（与 `HTTPExchangeStore.ensureStartedAtIndex` 同构）。
    ///
    /// ## 不建会怎样
    ///
    /// SwiftData 不会为「等值列 + 排序列」的组合自动建索引。没有这个索引时，
    /// 按会话取消息的查询计划是 `SCAN ZMESSAGEMODEL` + `USE TEMP B-TREE FOR ORDER BY`：
    /// 每次切换会话都要把整张消息表（生产库 5.6 万行 / 400MB）扫一遍再排序，
    /// 实测单次 180–270ms；建上索引后降到 0–34ms。
    ///
    /// 列顺序与排序方向必须与查询一致：等值的 `ZCONVERSATIONID` 在前，
    /// 排序列 `ZCREATEDAT DESC, ZID DESC` 在后，索引才能同时承担过滤与排序，
    /// 不再需要临时 B-tree。`ZID` 作为次级排序键保证同一时间戳下的稳定分页。
    private static func ensureConversationLookupIndex(at url: URL) {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database {
                Self.logger.error("消息库 SQLite 索引连接失败: \(String(cString: sqlite3_errmsg(database)))")
                sqlite3_close(database)
            } else {
                Self.logger.error("消息库 SQLite 索引连接失败，错误码: \(openResult)")
            }
            return
        }
        defer { sqlite3_close(database) }

        let sql = """
        CREATE INDEX IF NOT EXISTS ZMESSAGE_CONVERSATION_CREATED \
        ON ZMESSAGEMODEL (ZCONVERSATIONID, ZCREATEDAT DESC, ZID DESC)
        """
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            Self.logger.error("消息库 SQLite 索引创建失败: \(message)")
            return
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

    /// 返回某会话第一条用户消息，仅物化一条记录，供自动标题等轻量读取使用。
    func fetchFirstUserMessage(conversationId: UUID) -> Message? {
        locked {
            let context = ModelContext(container)
            let conversationIdString = conversationId.uuidString
            var descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> {
                    $0.conversationId == conversationIdString && $0.role == "user"
                },
                sortBy: [
                    SortDescriptor(\.createdAt, order: .forward),
                    SortDescriptor(\.id, order: .forward),
                ]
            )
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor))?.first?.toMessage()
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

    /// 原子地聚合日统计，并报告 `pendingIDs` 中**已落盘**的那些。
    ///
    /// `MessageManager` 的日统计口径是「磁盘聚合 + 未落盘 pending 增量」。
    /// 但 `persistLater` 分两步（先落盘、再移出 pending），中间存在窗口：
    /// 磁盘**已**含该消息、pending**仍**保留它。此时若两侧简单相加，
    /// 同一条会被统计两次——实测 20 轮中第 13 轮 `dailyTokenCounts` 得到 27
    /// （应为 17，input 的 10 被算了两遍）。
    ///
    /// - Important: 去重判据与聚合必须**在同一个 `locked` 块内**完成。
    ///   若先逐条 `fetchMessage` 探测再另行聚合，两者之间仍有窗口：
    ///   探测说「未落盘」、随后聚合却已包含它 → 漏算（实测 `dailyMessageCounts`
    ///   偶发少 1）。因此这里一次 fetch、一次判定，顺带返回「哪些 pending 已落盘」。
    ///
    /// - Important: 聚合结果**仍按磁盘实际行计入**这批 pending 消息
    ///   （不排除）。它们此刻既在磁盘、又在 pending，计一次即正确；
    ///   调用方据此**跳过**它们即可达成去重。若此处排除、调用方又跳过，
    ///   同一条会从两侧同时消失 → 少算。
    ///
    /// - Parameter countTokens: 为 true 时聚合 token 数，否则聚合消息条数。
    /// - Returns: 聚合结果 + `pendingIDs` 中已落盘（已在上面计入）的 id 集合。
    func dailyAggregate(
        since: Date,
        pendingIDs: Set<String>,
        countTokens: Bool
    ) -> (counts: [Date: Int], alreadyPersisted: Set<String>) {
        locked {
            let context = ModelContext(container)
            let timestamp = since.timeIntervalSince1970
            var descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> { $0.createdAt >= timestamp }
            )
            descriptor.propertiesToFetch = countTokens
                ? [\.id, \.createdAt, \.inputTokenCount, \.outputTokenCount]
                : [\.id, \.createdAt]

            guard let models = try? context.fetch(descriptor) else {
                // 取不到磁盘数据：全部交给 pending 侧补齐，diskCounts 为空。
                return ([:], [])
            }

            var alreadyPersisted: Set<String> = []
            let calendar = Calendar.current
            var counts: [Date: Int] = [:]
            for model in models {
                let value = countTokens
                    ? (model.inputTokenCount ?? 0) + (model.outputTokenCount ?? 0)
                    : 1
                // - Important: 先判 value 再记 id。若反序，0-token 的消息会被标记
                //   为「已计入」却实际没进 counts，调用方又跳过它 → 两侧同时丢失。
                guard value > 0 else { continue }
                if pendingIDs.contains(model.id) {
                    // 已计入下面的 counts，调用方不要再补一次。
                    alreadyPersisted.insert(model.id)
                }
                let day = calendar.startOfDay(for: Date(timeIntervalSince1970: model.createdAt))
                counts[day, default: 0] += value
            }
            return (counts, alreadyPersisted)
        }
    }

    /// 返回指定日期（含）以来、按本地自然日聚合的消息数。
    func dailyMessageCounts(since: Date) -> [Date: Int] {
        locked {
            let context = ModelContext(container)
            let timestamp = since.timeIntervalSince1970
            var descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> { $0.createdAt >= timestamp }
            )
            descriptor.propertiesToFetch = [\.createdAt]
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
            var descriptor = FetchDescriptor<MessageModel>(
                predicate: #Predicate<MessageModel> { $0.createdAt >= timestamp }
            )
            descriptor.propertiesToFetch = [\.createdAt, \.inputTokenCount, \.outputTokenCount]
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
