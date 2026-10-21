import Foundation
import SQLite3
import Testing
@testable import PluginMessageManager

/// 消息库「按会话取消息」必须走索引，不能退化成全表扫描。
///
/// ## 背景
///
/// 生产库 `messages.sqlite` 有 5.6 万行 / 400MB，而 `ZMESSAGEMODEL` **一个索引都没有**
/// （只有 CoreData 自己的 `ACHANGE` / `ATRANSACTION` 表带索引）。SwiftData 不会为
/// 「等值列 + 排序列」的组合自动建索引，于是每次切换会话的首屏分页查询都是
/// `SCAN ZMESSAGEMODEL` + `USE TEMP B-TREE FOR ORDER BY`：实测单次 180–270ms，
/// 建上 `(ZCONVERSATIONID, ZCREATEDAT DESC, ZID DESC)` 后降到 0–34ms。
///
/// ## 为什么断言查询计划而不是耗时
///
/// 耗时断言会随机器负载、磁盘与并发测试而抖动；查询计划是**确定性**的事实，
/// 直接表达「这条查询不许全表扫描」这个不变式。
@Suite("MessageStore 会话查询索引")
struct MessageStoreQueryIndexTests {
    /// SwiftData 为 `MessageModel` 生成的表名。
    private static let messageTable = "ZMESSAGEMODEL"

    private func makeStore() throws -> (store: MessageStore, directory: URL, databaseURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreIndex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try MessageStore(databaseRootURL: directory)
        let databaseURL = directory.appendingPathComponent("messages.sqlite")
        return (store, directory, databaseURL)
    }

    @Test("消息库必须建立 (会话, 创建时间) 复合索引")
    func storeCreatesConversationLookupIndex() throws {
        let (store, directory, databaseURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = store

        let indexes = try readIndexColumns(at: databaseURL)
        let hasCompositeIndex = indexes.contains { columns in
            columns.contains("ZCONVERSATIONID") && columns.contains("ZCREATEDAT")
        }

        #expect(
            hasCompositeIndex,
            """
            ZMESSAGEMODEL 上缺少 (ZCONVERSATIONID, ZCREATEDAT) 复合索引，\
            按会话取消息会退化成全表扫描。现有索引列：\(indexes)
            """
        )
    }

    @Test("按会话倒序取消息的查询计划必须使用索引")
    func conversationPageQueryPlanUsesIndex() throws {
        let (store, directory, databaseURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = store

        // 与 `fetchMessagePage` 首屏分页同构的查询：等值过滤 + 倒序 + LIMIT。
        let plan = try readQueryPlan(
            at: databaseURL,
            sql: """
            SELECT Z_PK FROM \(Self.messageTable) \
            WHERE ZCONVERSATIONID = ? \
            ORDER BY ZCREATEDAT DESC, ZID DESC \
            LIMIT 41
            """
        )

        #expect(
            !plan.contains("SCAN \(Self.messageTable)"),
            "查询计划退化成全表扫描：\(plan)"
        )
        #expect(
            plan.contains("USING INDEX"),
            "查询计划未使用索引：\(plan)"
        )
    }

    // MARK: - SQLite 读取辅助

    /// 读出 `sqlite_master` 中挂在消息表上的全部索引及其列。
    private func readIndexColumns(at databaseURL: URL) throws -> [[String]] {
        try withDatabase(at: databaseURL) { database in
            let names = try queryStrings(
                database,
                column: 0,
                sql: """
                SELECT name FROM sqlite_master \
                WHERE type = 'index' AND tbl_name = '\(Self.messageTable)' \
                AND sql IS NOT NULL
                """
            )
            return try names.map { name in
                // PRAGMA index_info 返回 (seqno, cid, name)，列名在第 3 列。
                try queryStrings(database, column: 2, sql: "PRAGMA index_info(\"\(name)\")")
            }
        }
    }

    /// 读出 `EXPLAIN QUERY PLAN` 的每一行描述。
    private func readQueryPlan(at databaseURL: URL, sql: String) throws -> String {
        try withDatabase(at: databaseURL) { database in
            // EXPLAIN QUERY PLAN 返回 (id, parent, notused, detail)，详情在第 4 列。
            try queryStrings(database, column: 3, sql: "EXPLAIN QUERY PLAN \(sql)")
                .joined(separator: " | ")
        }
    }

    /// 以只读方式打开数据库；只读连接不会与 SwiftData 持有的写事务抢锁。
    private func withDatabase<T>(at url: URL, _ body: (OpaquePointer) throws -> T) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MessageStoreError.initializationFailed("测试用消息数据库不存在：\(url.path)")
        }
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil)
        guard openResult == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            throw MessageStoreError.initializationFailed("消息数据库只读连接失败，错误码：\(openResult)")
        }
        defer { sqlite3_close(database) }
        return try body(database)
    }

    /// 执行一条查询并取回指定列的全部文本值。
    private func queryStrings(_ database: OpaquePointer, column: Int32, sql: String) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MessageStoreError.initializationFailed(
                "SQL 准备失败：\(String(cString: sqlite3_errmsg(database)))（\(sql)）"
            )
        }
        defer { sqlite3_finalize(statement) }

        var values: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, column) else { continue }
            values.append(String(cString: text))
        }
        return values
    }
}
