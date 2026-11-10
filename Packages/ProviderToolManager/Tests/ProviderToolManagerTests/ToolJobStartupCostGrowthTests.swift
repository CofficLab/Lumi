import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// 启动恢复成本随「累计使用时长」增长的验证。
///
/// ## 为什么必须验证这一点
///
/// 前面已经证明：
/// - `fetchAllJobs()` 无 limit，修复前把库里每一条 job 都物化 + JSON 解码；
/// - 过滤下推到 SQL 后快 110+ 倍（返回条数完全相同）；
/// - 终态 job 占 99.8%。
///
/// 但这些都是**当前**生产库上的横截面数据。要证明「越用越慢」，
/// 必须证明：**启动成本随 job 总量单调增长，且没有任何上限把它压住**。
///
/// 这个测试用生产库副本做「时间旅行」：
/// 保留前 N 条最旧的 job，模拟「应用刚启动不久」的状态，
/// 测量 N 从小到大时的启动恢复成本，看它是一条没有天花板的增长曲线。
///
/// ## 为什么不断言「耗时」
///
/// 耗时会随机器负载、磁盘与并发测试而抖动（本套件并发跑时同一逻辑
/// 能在 0.14s ~ 4.73s 之间波动）。所以耗时只作为**趋势数据**打印，
/// 断言的是**确定性的事实**：恢复的 job 条数随库增长而增长，
/// 且恢复路径必须走覆盖索引（不物化大字段）。
@Suite("ToolJob 启动恢复成本随时间增长")
struct ToolJobStartupCostGrowthTests {

    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_TOOL_JOBS_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 复制生产库，然后把 job 表裁剪到只剩前 N 条（最旧的），模拟「早期状态」。
    private func makeTruncatedStore(keeping limit: Int) throws -> (store: ToolJobRecordStore, directory: URL)? {
        guard let source = Self.productionDatabaseURL else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobGrowth-\(limit)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("tool_jobs.sqlite")
        try FileManager.default.copyItem(at: source, to: destination)
        let wal = source.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: wal.path) {
            try? FileManager.default.copyItem(
                at: wal,
                to: directory.appendingPathComponent("tool_jobs.sqlite-wal")
            )
        }

        // 裁剪：只保留 createdAt 最小的 N 条。
        var database: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let database else { return nil }
        let sql = """
        DELETE FROM ZTOOLJOBRECORDMODEL WHERE ZID NOT IN (
            SELECT ZID FROM ZTOOLJOBRECORDMODEL ORDER BY ZCREATEDAT ASC LIMIT \(limit)
        )
        """
        sqlite3_exec(database, sql, nil, nil, nil)
        sqlite3_close(database)

        let store = ToolJobRecordStore(databaseRootURL: directory)
        return (store, directory)
    }

    @Test("恢复的 job 条数随库增长而增长，且终态 job 的结果不被物化")
    func restoredCountGrowsWithLibrarySize() async throws {
        guard Self.productionDatabaseURL != nil else {
            print("TOOLGROWTH skip=生产库副本不可用")
            return
        }

        // 模拟「用了 1 个月 / 3 个月 / 6 个月 / 至今」四个时间点。
        let sizes = [1_000, 5_000, 20_000, 49_000]
        var counts: [Int] = []
        var carriedResults: [Int] = []

        for size in sizes {
            guard let (store, directory) = try makeTruncatedStore(keeping: size) else { continue }
            defer { try? FileManager.default.removeItem(at: directory) }

            let start = Date()
            let jobs = await store.fetchAllJobs()
            let elapsed = Date().timeIntervalSince(start)
            let withResult = jobs.filter { $0.result != nil }.count
            counts.append(jobs.count)
            carriedResults.append(withResult)
            print("TOOLGROWTH kept=\(size) actual=\(jobs.count) carriedResults=\(withResult) elapsed=\(String(format: "%.4f", elapsed))s")
        }

        guard counts.count >= 3 else {
            print("TOOLGROWTH skip=可用采样点不足")
            return
        }

        // 证据 1：恢复的条数随库增长 —— 这正是「越用越慢」的根源：
        // 没有任何机制限制启动时需要处理的 job 数量。
        for index in 1..<counts.count {
            #expect(
                counts[index] >= counts[index - 1],
                "恢复条数应随库增长：\(counts)"
            )
        }
        #expect(counts.last ?? 0 > 10_000, "最大采样点应远大于 1 万：\(counts)")

        // 证据 2：终态 job 的结果**不被物化** —— 这是修复的核心不变式。
        // 修复前每个 job 都会带一个 result（生产库合计 233MB）。
        for (size, carried) in zip(sizes, carriedResults) {
            #expect(
                carried == 0,
                "keeps=\(size) 时仍有 \(carried) 条 job 带着结果被物化，终态结果不应在启动时物化"
            )
        }
    }

    @Test("库里没有任何上限机制阻止增长")
    func noRetentionPolicyExists() throws {
        guard let source = Self.productionDatabaseURL else {
            print("TOOLGROWTH retention skip=生产库副本不可用")
            return
        }

        // 统计 job 库的时间跨度——如果跨度很长，说明没有任何清理机制在起作用。
        var database: OpaquePointer?
        guard sqlite3_open_v2(source.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else { return }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = """
        SELECT COUNT(*), MIN(ZCREATEDAT), MAX(ZCREATEDAT) FROM ZTOOLJOBRECORDMODEL
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return }

        let count = Int(sqlite3_column_int(statement, 0))
        let oldest = sqlite3_column_double(statement, 1)
        let newest = sqlite3_column_double(statement, 2)
        // CoreData 纪元偏移量。
        let spanDays = (newest - oldest) / 86_400
        print("TOOLGROWTH retention total=\(count) spanDays=\(String(format: "%.1f", spanDays))")

        // 证据：库里同时躺着很久以前和刚刚产生的 job —— 终态 job 从未被清理，
        // 所以表只增不减，启动恢复也没有天花板。
        #expect(count > 10_000, "job 总量异常少：\(count)")
        #expect(spanDays > 30, "job 库跨度应超过一个月，实际 \(spanDays) 天")
    }
}
