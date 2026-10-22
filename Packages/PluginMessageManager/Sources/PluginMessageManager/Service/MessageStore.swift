import Foundation
import os
import ProviderMessage
import LumiLoggingKit
import SQLite3
import SwiftData

/// `sqlite3_bind_text` 的析构回调：告诉 SQLite「绑定后请自行拷贝一份」。
///
/// Swift 的 SQLite3 模块没有导出 `SQLITE_TRANSIENT` 宏，这里按其定义
/// （即 `(void*)-1`）构造等价值。
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
    /// 消息库文件路径——日统计聚合的原生 SQL 快路径直接读它。
    private let databaseURL: URL
    private let lock = NSLock()

    // MARK: - Initialization

    public init(databaseRootURL: URL) throws {
        // `databaseRootURL` 已是插件专属数据目录，数据库文件固定为 messages.sqlite。
        let databaseURL = databaseRootURL.appendingPathComponent("messages.sqlite")
        self.databaseURL = databaseURL
        self.container = try Self.makeContainer(
            databaseRootURL: databaseRootURL,
            databaseURL: databaseURL
        )
    }

    /// Runs `body` while holding the store lock, making each operation atomic
    /// with respect to other callers.
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    static func makeContainer(databaseRootURL: URL, databaseURL: URL) throws -> ModelContainer {
        let schema = Schema([MessageModel.self])
        // `databaseRootURL` 已是插件专属数据目录（由调用方通过
        // `StorageProviding.pluginDataDirectory(for:)` 传入），直接作为数据库目录，
        // 不再追加插件名子目录（对齐 ConversationStore 的写法）。
        let dbDir = databaseRootURL
        let dbURL = databaseURL
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

    /// 按本地自然日聚合消息条数或 token 总数。
    ///
    /// - Parameters:
    ///   - since: 只统计创建时间不早于该时刻的消息。
    ///   - excludingIDs: 这些消息 id **不计入**磁盘侧结果——它们由调用方按 pending
    ///     口径补计，于是「同一条消息恰好被算一次」。
    ///   - countTokens: 为 true 时聚合 token 总数，否则聚合消息条数。
    ///
    /// - Important: 磁盘侧**按 id 排除** pending，而不是「先算进磁盘、再回报哪些
    ///   已落盘让调用方跳过」。两种做法在单次快照下等价，但排除法与两侧快照的
    ///   先后顺序无关：pending 里的消息无论此刻是否已落盘，都只由 pending 侧计一次。
    ///   旧做法在「消息已移出 pending、磁盘尚不可见」的窗口会两侧都不计 → 少算。
    ///
    /// - Important: 走原生 SQL 只取「创建时间 + token 数」，不物化整表。旧实现用
    ///   SwiftData 取回区间内全部行（生产库 5.6 万行 / 400MB → 4.6 秒），且全程
    ///   持有存储层写锁，把所有消息写入堵住近 5 秒。
    func dailyAggregate(
        since: Date,
        excludingIDs: Set<String>,
        countTokens: Bool
    ) -> [Date: Int] {
        if let counts = dailyAggregateViaSQL(
            since: since,
            excludingIDs: excludingIDs,
            countTokens: countTokens
        ) {
            return counts
        }
        // 原生 SQL 不可用（库结构变化 / 连接失败）→ 回退到 SwiftData 口径（慢但一致）。
        return dailyAggregateViaCoreData(
            since: since,
            excludingIDs: excludingIDs,
            countTokens: countTokens
        )
    }

    /// 返回指定日期（含）以来、按本地自然日聚合的消息数。
    func dailyMessageCounts(since: Date) -> [Date: Int] {
        dailyAggregate(since: since, excludingIDs: [], countTokens: false)
    }

    /// 返回指定日期（含）以来、按本地自然日聚合的输入与输出 token 总数。
    func dailyTokenCounts(since: Date) -> [Date: Int] {
        dailyAggregate(since: since, excludingIDs: [], countTokens: true)
    }

    /// 原生 SQL 快路径：只读「创建时间 + token 数」，逐行在 Swift 侧按自然日聚合。
    ///
    /// - Important: 这条路径**不持有存储层写锁**——它只读 SQLite，不碰 SwiftData
    ///   的 ModelContext。WAL 模式下读不阻塞写，聚合因此不会拖住消息落盘。
    ///
    /// - Returns: nil 表示这条路不可用（连接失败 / 语句失败 / 库结构不符），
    ///   调用方应回退到 SwiftData 口径。
    private func dailyAggregateViaSQL(
        since: Date,
        excludingIDs: Set<String>,
        countTokens: Bool
    ) -> [Date: Int]? {
        // 排除条件用绑定参数，参数个数受 SQLite 变量上限约束；pending 缓冲无上限，
        // 极端情况下改走回退路径。
        guard excludingIDs.count <= Self.maxExcludedIDsForSQL else { return nil }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READWRITE,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return nil
        }
        defer { sqlite3_close(database) }
        // 可能与 SwiftData 侧的写入撞上：短暂等待而不是立刻失败。
        sqlite3_busy_timeout(database, 2000)

        let sql = Self.dailyAggregateSQL(countTokens: countTokens, excludingCount: excludingIDs.count)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, since.timeIntervalSince1970)
        for (offset, identifier) in excludingIDs.sorted().enumerated() {
            sqlite3_bind_text(statement, Int32(2 + offset), identifier, -1, sqliteTransient)
        }

        var counts: [Date: Int] = [:]
        var dayIndex = DayStartIndex()
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            let timestamp = sqlite3_column_double(statement, 0)
            let value = countTokens
                ? Int(sqlite3_column_int(statement, 1)) + Int(sqlite3_column_int(statement, 2))
                : 1
            // 0-token 的消息在 token 口径下不计入；若某天因此没有任何 token，
            // 该日不应出现在结果里（与旧口径一致）。
            if value > 0 {
                let day = dayIndex.dayStart(for: timestamp)
                counts[Date(timeIntervalSince1970: day), default: 0] += value
            }
            stepResult = sqlite3_step(statement)
        }
        // 中途失败（BUSY / IOERR）时结果是残缺的，必须回退而不是返回半份统计。
        guard stepResult == SQLITE_DONE else { return nil }
        return counts
    }

    /// SwiftData 回退路径：原生 SQL 不可用时使用，慢但口径一致。
    private func dailyAggregateViaCoreData(
        since: Date,
        excludingIDs: Set<String>,
        countTokens: Bool
    ) -> [Date: Int] {
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
                return [:]
            }

            let calendar = Calendar.current
            var counts: [Date: Int] = [:]
            for model in models {
                let value = countTokens
                    ? (model.inputTokenCount ?? 0) + (model.outputTokenCount ?? 0)
                    : 1
                guard value > 0 else { continue }
                if excludingIDs.contains(model.id) { continue }
                let day = calendar.startOfDay(for: Date(timeIntervalSince1970: model.createdAt))
                counts[day, default: 0] += value
            }
            return counts
        }
    }

    /// 聚合查询语句。
    ///
    /// - Important: 只 SELECT `ZCREATEDAT`（与 token 列）。SwiftData 生成的表把正文
    ///   `ZCONTENT` 排在 `ZCREATEDAT` **之后**，读正文列必须顺着记录跨过 overflow
    ///   页；只取前面的列则完全不碰正文，代价与正文体积无关。
    private static func dailyAggregateSQL(countTokens: Bool, excludingCount: Int) -> String {
        let columns = countTokens
            ? "ZCREATEDAT, ZINPUTTOKENCOUNT, ZOUTPUTTOKENCOUNT"
            : "ZCREATEDAT"
        var sql = "SELECT \(columns) FROM ZMESSAGEMODEL WHERE ZCREATEDAT >= ?"
        if excludingCount > 0 {
            let placeholders = Array(repeating: "?", count: excludingCount).joined(separator: ",")
            sql += " AND ZID NOT IN (\(placeholders))"
        }
        return sql
    }

    /// 单次聚合查询允许绑定的排除 id 个数（留足余量给 SQLite 的变量上限）。
    private static let maxExcludedIDsForSQL = 500

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

// MARK: - Day Start Index

/// 把时间戳映射到它所属「本地自然日」的起点。
///
/// - Important: 逐行调用 `Calendar.startOfDay` 是日统计聚合的主要 CPU 开销
///   （5.6 万行 ≈ 60ms Release，Debug 更慢）。消息在表里并非按时间有序，
///   「上一行还在同一天」这种单槽缓存命中率极低，因此这里维护一份
///   **已出现日期的有序边界数组**并二分查找：`Calendar` 调用次数从「行数」
///   降到「天数」（生产库 29 天）。
///
/// - Important: 语义与逐行调用 `Calendar.current.startOfDay(for:)` **完全一致**——
///   夏令时、闰日、非公历历法都交给 `Calendar` 处理，这里只做缓存与查找。
private struct DayStartIndex {
    private let calendar: Calendar
    /// 已缓存日期的起点（秒级时间戳），保持升序。
    private var starts: [TimeInterval] = []
    /// 与 `starts` 一一对应的「该日结束」时刻（次日起点）。
    private var ends: [TimeInterval] = []

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 返回时间戳所属自然日的起点（秒级时间戳）。
    mutating func dayStart(for timestamp: TimeInterval) -> TimeInterval {
        // 二分定位第一个 > timestamp 的下标；于是 low - 1 是最后一个 <= timestamp 的已缓存日期。
        var low = 0
        var high = starts.count
        while low < high {
            let mid = (low + high) / 2
            if starts[mid] <= timestamp {
                low = mid + 1
            } else {
                high = mid
            }
        }
        // 命中缓存：该日边界已算过，且时间戳确实落在这一日内。
        if low > 0, timestamp < ends[low - 1] {
            return starts[low - 1]
        }
        // 未命中：交给 Calendar 算出这一天的边界，再插到有序位置。
        // 插入点 low 满足「前面的日期都更早、后面的日期都更晚」，因此数组仍然有序。
        let dayStart = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)
        let dayEnd = nextDay.flatMap { calendar.startOfDay(for: $0) }
            ?? dayStart.addingTimeInterval(86_400)
        starts.insert(dayStart.timeIntervalSince1970, at: low)
        ends.insert(dayEnd.timeIntervalSince1970, at: low)
        return dayStart.timeIntervalSince1970
    }
}
