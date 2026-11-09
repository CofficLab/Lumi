import Foundation
import KitAgentTool
import SQLite3
import SwiftData

/// 使用独立 `tool_jobs.sqlite` 保存可恢复 Tool Job 状态的后台存储服务。
public actor ToolJobRecordStore {
    private static let maxOutputBytes = 64 * 1024

    /// CoreData 把 `Date` 存成「2001-01-01 起的秒数」，比 Unix 时间戳
    /// 多一个 978307200 的偏移量。原生 SQL 读取时必须补回来。
    private static let coreDataEpochOffset: TimeInterval = 978_307_200

    /// 终态状态名——用于把「非终态」过滤下推到 SQL。
    private static let terminalStatusNames = ["completed", "failed", "cancelled", "timedOut"]

    /// `nil` 表示持久化与内存容器都创建失败——此时服务安全降级为 no-op。
    private let modelContext: ModelContext?
    private var deletedConversationIDs: Set<String> = []
    nonisolated public let directory: URL
    /// 消息库文件路径——启动恢复的原生 SQL 快路径直接读它。
    private nonisolated let databaseURL: URL

    public init(databaseRootURL: URL) {
        try? FileManager.default.createDirectory(at: databaseRootURL, withIntermediateDirectories: true)
        self.directory = databaseRootURL

        let schema = Schema([ToolJobRecordModel.self])
        let storeURL = databaseRootURL.appendingPathComponent("tool_jobs.sqlite", isDirectory: false)
        self.databaseURL = storeURL
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let modelContext: ModelContext?
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            modelContext = ModelContext(container)
        } catch {
            let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: [memoryConfiguration]) {
                modelContext = ModelContext(container)
            } else {
                modelContext = nil
            }
        }
        modelContext?.autosaveEnabled = false
        self.modelContext = modelContext
        Self.ensureStartupLookupIndex(at: storeURL)
    }

    /// 测试用：直接注入上下文；`nil` 表示存储不可用。
    init(modelContext: ModelContext?, databaseRootURL: URL) {
        self.modelContext = modelContext
        self.directory = databaseRootURL
        self.databaseURL = databaseRootURL.appendingPathComponent("tool_jobs.sqlite", isDirectory: false)
        modelContext?.autosaveEnabled = false
    }

    /// 建立「按创建时间排序 + 只读身份列」所需的覆盖索引。
    ///
    /// ## 为什么必须手工建
    ///
    /// 1. SwiftData 不会为「排序列 + 多列投影」自动建索引。没有这个索引时，
    ///    启动恢复的查询是 `SCAN ZTOOLJOBRECORDMODEL` + `USE TEMP B-TREE FOR ORDER BY`：
    ///    每行都要参与排序，成本随 Job 总量线性增长。
    ///
    /// 2. 覆盖索引让查询**只读索引页**，完全不碰主表 —— 这是把
    ///    `resultJSON`（生产库合计 233MB、单条最大 3.9MB）排除在启动路径之外的
    ///    关键：即使索引失效回退到主表扫描，也只是退化成「读身份列」，
    ///    不会退化成「读全部大字段」。
    ///
    /// 索引列顺序与查询一致：排序列 `ZCREATEDAT` 在前，其余身份列在后，
    /// 索引才能同时承担排序与投影。
    private static func ensureStartupLookupIndex(at url: URL) {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            url.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return
        }
        defer { sqlite3_close(database) }

        let sql = """
        CREATE INDEX IF NOT EXISTS ZTOOLJOB_STARTUP \
        ON ZTOOLJOBRECORDMODEL (\
        ZCREATEDAT, ZID, ZTOOLCALLID, ZCONVERSATIONID, ZTURNID, ZTOOLNAME, \
        ZARGUMENTSJSON, ZSTATUS, ZSTARTEDAT, ZUPDATEDAT, ZCOMPLETEDAT, \
        ZLATESTOUTPUT, ZOUTPUTBYTECOUNT, ZPROCESSID, ZCANCELREQUESTED, ZERRORMESSAGE\
        )
        """
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        if let errorMessage {
            sqlite3_free(errorMessage)
        }
        guard result == SQLITE_OK else { return }
    }

    /// 创建或更新一条 Job 快照。按 Job ID 幂等写入。
    public func upsert(_ record: ToolJobRecord) {
        guard !deletedConversationIDs.contains(record.conversationID.uuidString) else { return }
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.id == record.id }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.update(with: record)
        } else {
            modelContext.insert(ToolJobRecordModel(record: record))
        }
        try? modelContext.save()
    }

    public func fetchRecord(forJobID jobID: String) -> ToolJobRecord? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.id == jobID }
        )
        return (try? modelContext.fetch(descriptor).first)?.flatMap { $0.value() }
    }

    /// 返回**非终态** Job 快照（含结果）。
    ///
    /// ## 为什么要走原生 SQL
    ///
    /// `isTerminal` 是 `ToolJobStatus` 的**计算属性**，SwiftData 的 `#Predicate`
    /// 无法把它下推到 SQL —— 过滤只能发生在物化之后。于是纯 SwiftData 实现会
    /// 把全部 49530 行连同 233MB 的 `resultJSON` 物化进内存，才丢掉 99.8%。
    ///
    /// 实测旧实现只比全量读取快 1.2 倍：`fetchAllJobs` 10.49s、
    /// `fetchNonTerminalJobs` 9.47s —— 两者成本几乎相同。
    ///
    /// 终态状态是**字符串**（`ToolJobStatus.rawValue`），可以直接写进 SQL，
    /// 让 SQLite 只返回那几十行。
    public func fetchNonTerminalJobs() -> [ToolJobRecord] {
        guard modelContext != nil else { return [] }
        return fetchCompleteNonTerminalJobsViaSQL()
    }

    /// 返回全部 Job 快照，供执行管理器在启动时恢复幂等索引。
    ///
    /// ## 为什么要走原生 SQL
    ///
    /// 启动恢复需要**全部** Job（终态的也要——`ToolExecutionManager.submit`
    /// 依赖 `jobsByID` 做幂等检查），但**不需要终态 Job 的结果**。
    ///
    /// 用 SwiftData 读取时，每一行都会被完整物化（连带 `resultJSON`），
    /// 而 `resultJSON` 在生产库合计 233MB、单条最大 3.9MB。实测启动恢复耗时
    /// 随 Job 总量线性增长且无天花板：1000 条 0.12s → 49000 条 7.67s。
    ///
    /// 用原生 SQL 只 SELECT 身份列（配合覆盖索引 `ZTOOLJOB_STARTUP`），
    /// 可以**完全不碰** `resultJSON`：生产库实测纯 SQL 读取 49617 行 0.077s。
    ///
    /// ## 为什么「非终态」也必须用同一条 SQL 取回
    ///
    /// 如果「先原生 SQL 筛出哪些行、再用 SwiftData 全表物化后过滤」，
    /// SwiftData 那一步仍会把全部 49617 行连同 233MB 的 `resultJSON`
    /// 物化进内存 —— 过滤下推就白做了（实测这一项就占 5.4s）。
    ///
    /// 所以过滤下推必须**贯穿到取数方式本身**。
    public func fetchAllJobs() -> [ToolJobRecord] {
        guard modelContext != nil else { return [] }
        let identities = fetchIdentitiesViaSQL()
        guard !identities.isEmpty else { return [] }

        // 非终态 Job 需要完整结果（`restore` 会用它构造「无法恢复」的失败结果），
        // 数量极少（生产库 82/49617），单独用原生 SQL 取。
        let nonTerminal = fetchCompleteNonTerminalJobsViaSQL()
        let nonTerminalByID = Dictionary(
            nonTerminal.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return identities.map { identity in
            nonTerminalByID[identity.id] ?? identity
        }
    }

    /// 用原生 SQL 读取全部 Job 的身份与状态字段，**不取 `resultJSON`**。
    private func fetchIdentitiesViaSQL() -> [ToolJobRecord] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        ) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT ZID, ZTOOLCALLID, ZCONVERSATIONID, ZTURNID, ZTOOLNAME, \
        ZARGUMENTSJSON, ZSTATUS, ZCREATEDAT, ZSTARTEDAT, ZUPDATEDAT, \
        ZCOMPLETEDAT, ZLATESTOUTPUT, ZOUTPUTBYTECOUNT, ZPROCESSID, \
        ZCANCELREQUESTED, ZERRORMESSAGE \
        FROM ZTOOLJOBRECORDMODEL ORDER BY ZCREATEDAT ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var records: [ToolJobRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let record = Self.decodeIdentityRow(statement) else { continue }
            records.append(record)
        }
        return records
    }

    /// 用原生 SQL 取**非终态** Job 的完整记录（含 `resultJSON`）。
    private func fetchCompleteNonTerminalJobsViaSQL() -> [ToolJobRecord] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        ) == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }

        let terminalList = Self.terminalStatusNames
            .map { "'\($0)'" }
            .joined(separator: ", ")
        let sql = """
        SELECT ZID, ZTOOLCALLID, ZCONVERSATIONID, ZTURNID, ZTOOLNAME, \
        ZARGUMENTSJSON, ZSTATUS, ZCREATEDAT, ZSTARTEDAT, ZUPDATEDAT, \
        ZCOMPLETEDAT, ZLATESTOUTPUT, ZOUTPUTBYTECOUNT, ZPROCESSID, \
        ZCANCELREQUESTED, ZERRORMESSAGE, ZRESULTJSON \
        FROM ZTOOLJOBRECORDMODEL \
        WHERE ZSTATUS NOT IN (\(terminalList)) \
        ORDER BY ZCREATEDAT ASC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var records: [ToolJobRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard var record = Self.decodeIdentityRow(statement) else { continue }
            // 只有非终态 Job 才需要结果，且数量极少（生产库 82/49617）。
            if let resultJSON = sqlite3_column_text(statement, 16) {
                record.result = Self.decodeResult(String(cString: resultJSON))
            }
            records.append(record)
        }
        return records
    }

    /// 解码 `resultJSON`。
    private static func decodeResult(_ value: String) -> ToolCallResult? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ToolCallResult.self, from: data)
    }

    /// 把一行 SQLite 记录解码成 `ToolJobRecord`（结果字段留空）。
    private static func decodeIdentityRow(_ statement: OpaquePointer?) -> ToolJobRecord? {
        guard let statement else { return nil }
        guard let idPointer = sqlite3_column_text(statement, 0),
              let conversationIDPointer = sqlite3_column_text(statement, 2),
              let toolNamePointer = sqlite3_column_text(statement, 4),
              let argumentsPointer = sqlite3_column_text(statement, 5),
              let statusPointer = sqlite3_column_text(statement, 6) else {
            return nil
        }

        let id = String(cString: idPointer)
        guard let conversationID = UUID(uuidString: String(cString: conversationIDPointer)),
              let status = ToolJobStatus(rawValue: String(cString: statusPointer)) else {
            return nil
        }

        func text(at index: Int32) -> String? {
            guard let pointer = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: pointer)
        }
        /// CoreData 的 `Date` 存的是「2001-01-01 起的秒数」，比 Unix 时间戳
        /// 多一个 978307200 的偏移量。解码时必须补回来，否则时间会落在 1995 年。
        func date(at index: Int32) -> Date? {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
            let raw = sqlite3_column_double(statement, index)
            return Date(timeIntervalSince1970: raw + coreDataEpochOffset)
        }

        let toolCallID = text(at: 1)
        let turnID = text(at: 3).flatMap(UUID.init(uuidString:))
        let argumentsJSON = String(cString: argumentsPointer)

        return ToolJobRecord(
            id: id,
            toolCallID: toolCallID,
            conversationID: conversationID,
            turnID: turnID,
            toolName: String(cString: toolNamePointer),
            argumentsJSON: argumentsJSON,
            argumentsHash: ToolJobRecord.makeArgumentsHash(argumentsJSON),
            status: status,
            createdAt: date(at: 7) ?? Date(),
            startedAt: date(at: 8),
            updatedAt: date(at: 9) ?? Date(),
            latestOutput: text(at: 11) ?? "",
            outputByteCount: Int(sqlite3_column_int64(statement, 12)),
            processID: sqlite3_column_type(statement, 13) == SQLITE_NULL
                ? nil
                : Int32(sqlite3_column_int(statement, 13)),
            cancelRequested: sqlite3_column_int(statement, 14) != 0,
            completedAt: date(at: 10),
            result: nil,
            errorMessage: text(at: 15)
        )
    }

    public func fetchJobs(forConversationID conversationID: UUID) -> [ToolJobRecord] {
        guard let modelContext else { return [] }
        let conversationIDString = conversationID.uuidString
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.conversationID == conversationIDString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.compactMap { $0.value() }
    }

    public func fetchJobs(forTurnID turnID: UUID) -> [ToolJobRecord] {
        guard let modelContext else { return [] }
        let turnIDString = turnID.uuidString
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.turnID == turnIDString },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let models = try? modelContext.fetch(descriptor) else { return [] }
        return models.compactMap { $0.value() }
    }

    public func deleteAll(for conversationID: UUID) {
        guard let modelContext else { return }
        let conversationIDString = conversationID.uuidString
        deletedConversationIDs.insert(conversationIDString)
        let descriptor = FetchDescriptor<ToolJobRecordModel>(
            predicate: #Predicate<ToolJobRecordModel> { $0.conversationID == conversationIDString }
        )
        guard let models = try? modelContext.fetch(descriptor) else { return }
        for model in models {
            modelContext.delete(model)
        }
        try? modelContext.save()
    }

    /// 统一截断输出尾部，避免失控命令耗尽 Job 数据库。
    public static func boundedOutput(_ output: String) -> String {
        let data = Data(output.utf8)
        return String(decoding: data.suffix(maxOutputBytes), as: UTF8.self)
    }
}
