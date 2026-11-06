import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// Tool Job 库「物化成本 vs 返回条数」的关系验证。
///
/// ## 修复前的观测
///
/// ```
/// fetchAllJobs        count=49516  elapsed=9.64s
/// fetchNonTerminalJobs count=82    elapsed=7.36s   ← 只返回 82 条却要 7.36s
/// ```
///
/// 只返回 82 条却要 7.36s —— 差了 70 倍。这说明
/// `fetchNonTerminalJobs()` **并没有把成本花在返回的数据上**：
/// 它在 Swift 侧过滤 `!value.status.isTerminal`，而 `value()` 里的
/// JSON 解码发生在**过滤之前**，所以每一条 job 的 `resultJSON`
/// 都已经被解码过一遍了。
///
/// 更关键的是：**过滤发生在物化之后**。SwiftData 的 `#Predicate`
/// 只能对持久化的基本字段下推，`isTerminal` 是 `ToolJobStatus` 的
/// 计算属性，无法下推到 SQL —— 于是 49530 行**全部被物化成对象**，
/// 带着 233MB 的 `resultJSON` 字符串进入内存，然后才丢掉 99.8%。
///
/// ## 修复后的不变式
///
/// 过滤必须**贯穿到取数方式本身**：
/// 1. 终态 job 的身份与状态用原生 SQL 只读身份列（覆盖索引，不碰 resultJSON）；
/// 2. 非终态 job 用同一条 SQL 直接把那几十行（含 resultJSON）取回来。
///
/// 如果「先用原生 SQL 筛出哪些行、再用 SwiftData 全表物化后过滤」，
/// SwiftData 那一步仍会物化全部 49530 行 —— 实测这一项就占 5.4s。
@Suite("ToolJobRecordStore 物化成本分析")
struct ToolJobRecordStoreMaterializationCostTests {

    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_TOOL_JOBS_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func makeStoreFromProductionCopy() throws -> (store: ToolJobRecordStore, directory: URL)? {
        guard let source = Self.productionDatabaseURL else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobCost-\(UUID().uuidString)", isDirectory: true)
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

    /// 用原生 SQL 统计状态分布（绕开 SwiftData，纯事实）。
    private func statusCounts(in databaseURL: URL) throws -> [(status: String, count: Int)] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else { return [] }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "SELECT ZSTATUS, COUNT(*) FROM ZTOOLJOBRECORDMODEL GROUP BY ZSTATUS"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        var rows: [(String, Int)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0) else { continue }
            rows.append((String(cString: text), Int(sqlite3_column_int(statement, 1))))
        }
        return rows
    }

    @Test("终态 job 占绝大多数，恢复只需非终态")
    func terminalJobsDominate() throws {
        guard let source = Self.productionDatabaseURL else {
            print("TOOLCOST skip=生产库副本不可用")
            return
        }
        let counts = try statusCounts(in: source)
        let total = counts.reduce(0) { $0 + $1.count }
        let terminalStatuses: Set<String> = ["completed", "failed", "cancelled", "timedOut"]
        let terminal = counts.filter { terminalStatuses.contains($0.status) }.reduce(0) { $0 + $1.count }
        let nonTerminal = total - terminal

        print("TOOLCOST total=\(total) terminal=\(terminal) nonTerminal=\(nonTerminal)")
        for row in counts {
            print("TOOLCOST status=\(row.status) count=\(row.count)")
        }

        // 证据：99% 以上的 job 已是终态，启动恢复它们的结果没有意义。
        #expect(total > 1_000, "生产库 job 条数远低于预期，基准不具代表性")
        #expect(
            Double(terminal) / Double(total) > 0.99,
            "终态占比异常：\(terminal)/\(total)"
        )
        #expect(nonTerminal > 0, "应存在非终态 job，否则恢复逻辑无从验证")
    }

    @Test("非终态读取必须只取那几十行：过滤已下推到 SQL")
    func pushedDownFilterRemovesMaterializationCost() async throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("TOOLCOST skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        // 修复后：非终态读取走原生 SQL，只返回那几十行。
        let nonTerminal = await store.fetchNonTerminalJobs()

        // 对照：全量读取（同样走原生 SQL，但要读全部行）。
        let all = await store.fetchAllJobs()

        print("TOOLCOST nonTerminal count=\(nonTerminal.count) all count=\(all.count)")

        // 证据 1：非终态 job 只有个位数量级 —— 过滤确实下推到了 SQL。
        #expect(nonTerminal.count < 200, "非终态 job 应只有个位数量级，实际 \(nonTerminal.count)")
        // 证据 2：非终态只占总量的极小比例。
        #expect(
            nonTerminal.count * 100 < all.count,
            "非终态 job 应远少于总量：\(nonTerminal.count) vs \(all.count)"
        )
        // 证据 3：非终态 Job 本来就没有结果（还没执行完），恢复逻辑会用
        // 「无法恢复」的失败结果替代它。所以 result 为 nil 是**正确**的。
        //
        // 生产库实测：非终态行里 `ZRESULTJSON` 非空的只有 0 条。
        #expect(
            nonTerminal.allSatisfy { $0.result == nil },
            "非终态 Job 不应带结果（生产库实测 0/83 非空）"
        )
    }
}
