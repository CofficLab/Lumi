import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// `tool_jobs` 表按 `createdAt` 排序的查询必须走索引，不能全表扫描 + 临时排序。
///
/// ## 背景
///
/// `tool_jobs.sqlite` 随使用单调增长（生产库实测 49652 条 / 跨度 50 天），
/// 而 **CoreData 不会为 `Date` 列自动建索引** —— `ZTOOLJOBRECORDMODEL` 上
/// 只有 CoreData 自己的 `ACHANGE` / `ATRANSACTION` 辅助表带索引，
/// 业务表本身一个索引都没有。
///
/// 于是任何 `ORDER BY ZCREATEDAT` 的查询都是：
///
/// ```
/// SCAN ZTOOLJOBRECORDMODEL
/// `--USE TEMP B-TREE FOR ORDER BY
/// ```
///
/// 每行都要参与排序，成本随 job 总量线性增长。
///
/// ## 这个测试断言什么
///
/// 断言**查询计划**而不是耗时 —— 耗时会随机器负载、磁盘与并发测试抖动，
/// 而查询计划是确定性的事实，直接表达「这条查询不许全表扫描」这个不变式。
///
/// 覆盖三类排序查询：
/// 1. 启动恢复（原生 SQL，只读身份列）—— 必须走**覆盖**索引；
/// 2. 按会话查（原生 SQL，带等值过滤）；
/// 3. 按 turn 查（原生 SQL，带等值过滤）。
@Suite("tool_jobs 排序查询的索引")
struct ToolJobSortIndexTests {

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobSortIndex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 建一个装了若干 job 的库（走 `ToolJobRecordStore`，索引由它创建）。
    private func makeStoreWithJobs(count: Int = 500) async throws -> (store: ToolJobRecordStore, directory: URL) {
        let directory = try Self.makeTemporaryDirectory()
        let store = ToolJobRecordStore(databaseRootURL: directory)
        let conversationID = UUID()
        let turnID = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<count {
            await store.upsert(ToolJobRecord(
                id: "job-\(index)",
                toolCallID: "call-\(index)",
                conversationID: conversationID,
                turnID: turnID,
                toolName: "run_command",
                argumentsJSON: "{}",
                argumentsHash: "hash",
                status: .completed,
                createdAt: base.addingTimeInterval(Double(index)),
                startedAt: base.addingTimeInterval(Double(index)),
                updatedAt: base.addingTimeInterval(Double(index)),
                latestOutput: "out"
            ))
        }
        return (store, directory)
    }

    /// 读出查询计划。
    private func queryPlan(in databaseURL: URL, sql: String) throws -> String {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            return ""
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "EXPLAIN QUERY PLAN \(sql)", -1, &statement, nil) == SQLITE_OK else {
            return ""
        }
        defer { sqlite3_finalize(statement) }

        var rows: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 3) {
                rows.append(String(cString: text))
            }
        }
        return rows.joined(separator: " | ")
    }

    @Test("启动恢复的排序查询必须走覆盖索引")
    func startupRestoreQueryUsesIndex() async throws {
        let (store, directory) = try await makeStoreWithJobs()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = await store.fetchAllJobs()

        let databaseURL = directory.appendingPathComponent("tool_jobs.sqlite")
        let plan = try queryPlan(in: databaseURL, sql: """
        SELECT ZID, ZTOOLCALLID, ZCONVERSATIONID, ZTURNID, ZTOOLNAME, \
        ZARGUMENTSJSON, ZSTATUS, ZCREATEDAT, ZSTARTEDAT, ZUPDATEDAT, \
        ZCOMPLETEDAT, ZLATESTOUTPUT, ZOUTPUTBYTECOUNT, ZPROCESSID, \
        ZCANCELREQUESTED, ZERRORMESSAGE \
        FROM ZTOOLJOBRECORDMODEL ORDER BY ZCREATEDAT ASC
        """)
        print("TOOLIDX startupPlan=\(plan)")

        #expect(
            plan.contains("COVERING INDEX"),
            "启动恢复的查询未使用覆盖索引：\(plan)"
        )
        #expect(
            !plan.contains("TEMP B-TREE"),
            "启动恢复的查询仍需临时排序：\(plan)"
        )
    }

    @Test("按会话查询的排序必须走索引")
    func conversationQueryUsesIndex() async throws {
        let (store, directory) = try await makeStoreWithJobs()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = await store.fetchAllJobs()

        let databaseURL = directory.appendingPathComponent("tool_jobs.sqlite")
        let plan = try queryPlan(in: databaseURL, sql: """
        SELECT ZID, ZSTATUS FROM ZTOOLJOBRECORDMODEL \
        WHERE ZCONVERSATIONID = 'some-id' ORDER BY ZCREATEDAT ASC
        """)
        print("TOOLIDX conversationPlan=\(plan)")

        #expect(
            !plan.contains("TEMP B-TREE"),
            "按会话查询仍需临时排序：\(plan)"
        )
        #expect(
            plan.contains("USING INDEX") || plan.contains("COVERING INDEX"),
            "按会话查询未使用索引：\(plan)"
        )
    }

    @Test("按 turn 查询的排序必须走索引")
    func turnQueryUsesIndex() async throws {
        let (store, directory) = try await makeStoreWithJobs()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = await store.fetchAllJobs()

        let databaseURL = directory.appendingPathComponent("tool_jobs.sqlite")
        let plan = try queryPlan(in: databaseURL, sql: """
        SELECT ZID, ZSTATUS FROM ZTOOLJOBRECORDMODEL \
        WHERE ZTURNID = 'some-id' ORDER BY ZCREATEDAT ASC
        """)
        print("TOOLIDX turnPlan=\(plan)")

        #expect(
            !plan.contains("TEMP B-TREE"),
            "按 turn 查询仍需临时排序：\(plan)"
        )
        #expect(
            plan.contains("USING INDEX") || plan.contains("COVERING INDEX"),
            "按 turn 查询未使用索引：\(plan)"
        )
    }
}
