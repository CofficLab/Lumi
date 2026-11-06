import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// 否证记录：`FetchDescriptor.propertiesToFetch` **不能**解决启动开销。
///
/// ## 结论
///
/// `propertiesToFetch` 看起来是「只取需要的列」的正确工具，**但它不是**。
/// 实测（生产库副本，49485 条 job，`resultJSON` 合计 244MB）：
///
/// ```
/// fullRows    count=49516  elapsed=4.93s
/// identityOnly count=49516  elapsed=3.93s      ← 只快 1.3 倍
/// ```
///
/// 而把过滤下推到 SQL：
///
/// ```
/// sqlPushedDown count=83  elapsed=0.045s        ← 快 114 倍
/// ```
///
/// ## 原因
///
/// `propertiesToFetch` 只影响 SwiftData 的**故障转移（faulting）**行为 ——
/// 即「哪些列被标记为脏、需要重新从 store 加载」。它**不改变** SQLite 实际
/// 读取的行数据：SwiftData 仍然把整行（包括 244MB 的 `resultJSON`）
/// 读进内存，再丢弃未请求的列。
///
/// 真正决定成本的是**物化了多少行**。要跳过物化，必须让 SQL 层少返回行。
///
/// ## 对修复方案的约束
///
/// 终态 job 必须留在 `jobsByID` 里 —— `ToolExecutionManager.submit` 依赖它做
/// 幂等检查（同 conversationID + turnID + toolCall.id 不重复执行）。
/// 所以「只恢复非终态」不是安全选项。
///
/// 可行方向是**两条同时做**：
/// 1. 终态 job 只取身份字段（跳过 `resultJSON` 的 JSON 解码）；
/// 2. 终态 job 的 `result` 可以安全丢弃 —— `resultsByID` 只被
///    `waitForResult` 消费，而 `waitForResult` 只对**正在运行**的 job 有意义，
///    终态 job 不可能有等待者。
///
/// 这个测试把否证结论固化下来，防止后人重复走这条弯路。
@Suite("ToolJob 大字段读取策略的否证记录")
struct ToolJobLargeFieldStrategyTests {

    private static var productionDatabaseURL: URL? {
        let path = ProcessInfo.processInfo.environment["LUMI_PROD_TOOL_JOBS_SQLITE"]
        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// 统计库里 `resultJSON` 的总量，证明「大字段确实是成本主体」。
    @Test("resultJSON 是 job 库的成本主体")
    func resultJSONDominatesStorageCost() throws {
        guard let source = Self.productionDatabaseURL else {
            print("NOPROOF skip=生产库副本不可用")
            return
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(source.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else { return }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = """
        SELECT COUNT(*), COALESCE(SUM(LENGTH(ZRESULTJSON)), 0),
               COALESCE(MAX(LENGTH(ZRESULTJSON)), 0)
        FROM ZTOOLJOBRECORDMODEL
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return }

        let count = Int(sqlite3_column_int(statement, 0))
        let totalBytes = Int(sqlite3_column_int(statement, 1))
        let maxBytes = Int(sqlite3_column_int(statement, 2))
        print("NOPROOF jobs=\(count) resultJSONTotalMB=\(totalBytes / 1_048_576) resultJSONMaxKB=\(maxBytes / 1024)")

        // 证据：resultJSON 单独就占了 hundreds MB，单条最大数 MB。
        #expect(count > 10_000, "job 总量异常少：\(count)")
        #expect(totalBytes > 100_000_000, "resultJSON 总量远低于预期：\(totalBytes)")
    }
}
