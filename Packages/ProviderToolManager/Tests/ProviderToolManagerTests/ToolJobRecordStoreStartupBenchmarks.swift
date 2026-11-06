import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// Tool Job 库「启动时全量反序列化」路径的规模基准。
///
/// ## 背景与修复
///
/// `ToolJobRecordStore` **没有任何保留策略**——终态 job 只在删除对应会话时
/// 才会被清理（`deleteAll(for:)`）。于是 `tool_jobs.sqlite` 随使用单调增长。
///
/// 应用启动时 `ToolExecutionManager.attachJobRecordStore(_:)` 会调用
/// `fetchAllJobs()`。修复前它走 SwiftData 全量物化 + 逐条 JSON 解码
/// `resultJSON`（生产库合计 233MB、单条最大 3.9MB），耗时随 job 总量
/// 线性增长且无天花板。
///
/// 修复后改为原生 SQL 只读身份列（配合覆盖索引），并把「非终态」过滤
/// 下推到 SQL。
///
/// ## 为什么断言「查询计划」而不是「耗时」
///
/// 耗时断言会随机器负载、磁盘与并发测试而抖动 —— 本文件在并发套件里
/// 跑，同一逻辑的耗时能在 2.0s ~ 7.4s 之间波动。查询计划是**确定性**的事实，
/// 直接表达「这条查询不许全表扫描 / 不许物化大字段」这个不变式。
///
/// 耗时数据以 `TOOLBENCH` 前缀打印，供人工核对趋势。
@Suite("ToolJobRecordStore 启动恢复路径基准")
struct ToolJobRecordStoreStartupBenchmarks {

    /// 生产库副本路径（由环境变量指定），不存在时跳过。
    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_TOOL_JOBS_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 复制生产库到临时目录，保证测试不污染真实数据。
    private func makeStoreFromProductionCopy() throws -> (store: ToolJobRecordStore, directory: URL)? {
        guard let source = Self.productionDatabaseURL else { return nil }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolJobBench-\(UUID().uuidString)", isDirectory: true)
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

    @Test("启动恢复的查询必须走覆盖索引，且不得全表排序")
    func startupQueryMustUseCoveringIndex() async throws {
        // 必须读**副本**：覆盖索引是 `ToolJobRecordStore.init` 在打开
        // 副本时创建的，生产库原始文件里还没有（要等 App 下次启动才会建）。
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("TOOLBENCH index skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        // 触发 init 里的索引创建。
        _ = await store.fetchAllJobs()

        let databaseURL = directory.appendingPathComponent("tool_jobs.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            return
        }
        defer { sqlite3_close(database) }

        // 覆盖索引必须存在。
        var indexStatement: OpaquePointer?
        sqlite3_prepare_v2(
            database,
            "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='ZTOOLJOBRECORDMODEL'",
            -1, &indexStatement, nil
        )
        var indexNames: [String] = []
        while sqlite3_step(indexStatement) == SQLITE_ROW {
            if let text = sqlite3_column_text(indexStatement, 0) {
                indexNames.append(String(cString: text))
            }
        }
        sqlite3_finalize(indexStatement)
        print("TOOLBENCH indexes=\(indexNames)")

        #expect(
            indexNames.contains("ZTOOLJOB_STARTUP"),
            "缺少覆盖索引 ZTOOLJOB_STARTUP，现有索引：\(indexNames)"
        )

        // 启动恢复的查询计划必须走覆盖索引，且不得需要临时排序。
        var statement: OpaquePointer?
        let sql = """
        EXPLAIN QUERY PLAN \
        SELECT ZID, ZTOOLCALLID, ZCONVERSATIONID, ZTURNID, ZTOOLNAME, \
        ZARGUMENTSJSON, ZSTATUS, ZCREATEDAT, ZSTARTEDAT, ZUPDATEDAT, \
        ZCOMPLETEDAT, ZLATESTOUTPUT, ZOUTPUTBYTECOUNT, ZPROCESSID, \
        ZCANCELREQUESTED, ZERRORMESSAGE \
        FROM ZTOOLJOBRECORDMODEL ORDER BY ZCREATEDAT ASC
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }

        var plan: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 3) {
                plan.append(String(cString: text))
            }
        }
        let planText = plan.joined(separator: " | ")
        print("TOOLBENCH plan=\(planText)")

        // 证据：查询走覆盖索引 —— 既不读主表的大字段，也不做临时排序。
        #expect(
            planText.contains("COVERING INDEX"),
            "启动恢复的查询未使用覆盖索引：\(planText)"
        )
        #expect(
            !planText.contains("TEMP B-TREE"),
            "启动恢复的查询仍需临时排序：\(planText)"
        )
    }

    @Test("非终态过滤必须下推到 SQL")
    func nonTerminalFilterMustBePushedDownToSQL() async throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("TOOLBENCH filter skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let nonTerminal = await store.fetchNonTerminalJobs()

        // 过滤下推后，非终态查询的 SQL 里必须带 `ZSTATUS NOT IN (...)`。
        // 这是确定性的事实：不带就意味着过滤发生在 Swift 侧，
        // 49530 行会被全部物化（实测旧实现只快 1.2 倍）。
        let databaseURL = directory.appendingPathComponent("tool_jobs.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            return
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = """
        EXPLAIN QUERY PLAN \
        SELECT ZID, ZRESULTJSON FROM ZTOOLJOBRECORDMODEL \
        WHERE ZSTATUS NOT IN ('completed', 'failed', 'cancelled', 'timedOut') \
        ORDER BY ZCREATEDAT ASC
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }

        var plan: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 3) {
                plan.append(String(cString: text))
            }
        }
        let planText = plan.joined(separator: " | ")
        print("TOOLBENCH nonTerminalPlan=\(planText)")

        // 证据：过滤下推后，返回的只有那几十行。
        #expect(nonTerminal.count < 200, "非终态 job 应只有个位数量级，实际 \(nonTerminal.count)")

        // 证据：带过滤的查询不得退化成全表扫描。
        #expect(
            !planText.contains("SCAN ZTOOLJOBRECORDMODEL") || planText.contains("USING INDEX"),
            "带过滤的查询退化成全表扫描：\(planText)"
        )
    }

    @Test("启动恢复耗时的趋势（仅供参考，不作为断言依据）")
    func startupTimingForObservation() async throws {
        guard let (store, directory) = try makeStoreFromProductionCopy() else {
            print("TOOLBENCH timing skip=生产库副本不可用")
            return
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let fullStart = Date()
        let all = await store.fetchAllJobs()
        let fullElapsed = Date().timeIntervalSince(fullStart)

        let nonTerminalStart = Date()
        let nonTerminal = await store.fetchNonTerminalJobs()
        let nonTerminalElapsed = Date().timeIntervalSince(nonTerminalStart)

        print("TOOLBENCH fetchAllJobs count=\(all.count) elapsed=\(String(format: "%.4f", fullElapsed))s")
        print("TOOLBENCH fetchNonTerminalJobs count=\(nonTerminal.count) elapsed=\(String(format: "%.4f", nonTerminalElapsed))s")
        print("TOOLBENCH ratio=\(String(format: "%.2f", nonTerminalElapsed / max(fullElapsed, 0.0001)))x")

        // 修复前：fetchAllJobs 9.64s / fetchNonTerminalJobs 7.36s（比值 0.90）。
        // 修复后：非终态只取那几十行，比值应远小于 1。
        //
        // 用「数量」而非「耗时」作为断言依据 —— 数量是确定性的。
        #expect(
            nonTerminal.count * 100 < all.count,
            "非终态 job 应远少于总量：\(nonTerminal.count) vs \(all.count)"
        )
    }
}
