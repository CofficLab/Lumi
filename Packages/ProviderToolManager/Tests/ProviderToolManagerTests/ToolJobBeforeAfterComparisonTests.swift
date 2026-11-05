import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// 修复前后的最终对比数据（生产库副本实测）。
///
/// 这个测试只**打印**数据，不做耗时断言 —— 耗时受机器负载影响太大。
/// 断言的是**确定性的事实**（物化条数、查询计划）。
@Suite("ToolJob 启动恢复：修复前后对比")
struct ToolJobBeforeAfterComparisonTests {

    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_TOOL_JOBS_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func makeStoreFromProductionCopy() throws -> (store: ToolJobRecordStore, directory: URL)? {
        guard let source = Self.productionDatabaseURL else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobCompare-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: source,
            to: directory.appendingPathComponent("tool_jobs.sqlite")
        )
        let wal = source.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: wal.path) {
            try? FileManager.default.copyItem(
                at: wal,
                to: directory.appendingPathComponent("tool_jobs.sqlite-wal")
            )
        }
        let store = ToolJobRecordStore(databaseRootURL: directory)
        return (store, directory)
    }

    @Test("终态 job 的结果不再在启动时被物化")
    func terminalResultsAreNotMaterialized() async throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("COMPARE skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let jobs = await store.fetchAllJobs()
        let withResult = jobs.filter { $0.result != nil }.count
        let terminal = jobs.filter { $0.status.isTerminal }.count

        print("COMPARE total=\(jobs.count) terminal=\(terminal) carriedResults=\(withResult)")

        // 修复前：每个终态 job 都带着 result（生产库合计 233MB）。
        // 修复后：0 个。
        #expect(
            withResult == 0,
            "仍有 \(withResult)/\(jobs.count) 条 job 带着结果被物化"
        )
    }

    @Test("查询走覆盖索引，不全表扫描")
    func queryUsesCoveringIndex() async throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("COMPARE index skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = await store.fetchAllJobs()

        let databaseURL = directory.appendingPathComponent("tool_jobs.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else { return }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = """
        EXPLAIN QUERY PLAN \
        SELECT ZID, ZTOOLCALLID, ZCONVERSATIONID, ZTURNID, ZTOOLNAME, \
        ZARGUMENTSJSON, ZSTATUS, ZCREATEDAT, ZSTARTEDAT, ZUPDATEDAT, \
        ZCOMPLETEDAT, ZLATESTOUTPUT, ZOUTPUTBYTECOUNT, ZPROCESSID, \
        ZCANCELREQUESTED, ZERRORMESSAGE \
        FROM ZTOOLJOBRECORDMODEL ORDER BY ZCREATEDAT ASC
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        var plan: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 3) {
                plan.append(String(cString: text))
            }
        }
        let planText = plan.joined(separator: " | ")
        print("COMPARE plan=\(planText)")

        // 修复前：SCAN ZTOOLJOBRECORDMODEL | USE TEMP B-TREE FOR ORDER BY
        #expect(
            planText.contains("COVERING INDEX"),
            "未使用覆盖索引：\(planText)"
        )
        #expect(
            !planText.contains("TEMP B-TREE"),
            "仍需临时排序：\(planText)"
        )
    }
}
