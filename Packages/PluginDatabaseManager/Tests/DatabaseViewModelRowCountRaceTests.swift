@testable import DatabaseManagerPlugin
import Foundation
import Testing

/// 后台 `SELECT COUNT(*)` 的行数竞态（回归 #565）。
///
/// ## 回归背景
///
/// 数据页在后台异步执行 `SELECT COUNT(*)` 填充共享的 `tableRowCount`。打开表 A 后
/// 快速切到表 B，A 的慢 COUNT 可能晚于 B 返回；若写回前不校验当前 `openTableObject`，
/// A 的行数会覆盖 B 的行数，分页 bar 据此算出错误的总页数与 Next 可用性。
/// `refreshTableRowCount` 必须在写回前比对 `openTableObject?.id == table.id` 与连接代次。
///
/// 假连接按表名返回固定计数，并可把指定表的 COUNT 挂起直到测试显式放行，
/// 从而确定性地构造「旧表的 COUNT 晚到」时序。
private actor RowCountConnection: DatabaseConnection {
    private let counts: [String: Int]
    private var gatedTable: String?
    private var gateStarted = false
    private var gateContinuation: CheckedContinuation<Void, Never>?
    private var gateReleased = false

    init(counts: [String: Int]) {
        self.counts = counts
    }

    /// 让下一次命中 `table` 的 COUNT 查询挂起。
    func armCountGate(table: String) {
        gatedTable = table
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        if sql.uppercased().hasPrefix("SELECT COUNT(*)") {
            let table = counts.keys.first { sql.contains($0) } ?? ""
            if table == gatedTable {
                gateStarted = true
                await withCheckedContinuation { continuation in
                    if gateReleased {
                        continuation.resume()
                    } else {
                        gateContinuation = continuation
                    }
                }
            }
            let count = counts[table] ?? 0
            return QueryResult(columns: ["count"], rows: [[.integer(count)]], rowsAffected: 1)
        }
        return QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }

    func beginTransaction() async throws -> any DatabaseTransaction { RowCountTransaction() }

    func close() async {}

    func isAlive() async -> Bool { true }

    func isClosed() -> Bool { false }

    func waitUntilCountGateStarts() async {
        while !gateStarted {
            await Task.yield()
        }
    }

    func releaseCountGate() {
        if let continuation = gateContinuation {
            gateContinuation = nil
            continuation.resume()
        } else {
            gateReleased = true
        }
    }
}

private struct RowCountTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}

private actor RowCountDriver: DatabaseDriver {
    nonisolated let type: DatabaseType
    private let connection: RowCountConnection

    init(type: DatabaseType, connection: RowCountConnection) {
        self.type = type
        self.connection = connection
    }

    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        connection
    }
}

@MainActor
@Suite("后台行数 COUNT 的表身份校验")
struct DatabaseViewModelRowCountRaceTests {

    private func makeSUT(counts: [String: Int]) async -> (
        viewModel: DatabaseViewModel,
        connection: RowCountConnection
    ) {
        let manager = DatabaseManagerCore()
        // 先注册内置驱动（标记该 manager 已注册），再用假驱动覆盖 sqlite，
        // 否则 connect() 内的 registerBuiltinsIfNeeded 会用真实 SQLiteDriver 覆盖假驱动。
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        let connection = RowCountConnection(counts: counts)
        let driver = RowCountDriver(type: .sqlite, connection: connection)
        await manager.register(driver: driver)
        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        let config = DatabaseConfig(name: "db", type: .sqlite, database: "db")
        await viewModel.connect(config: config)
        return (viewModel, connection)
    }

    private func table(_ name: String) -> DatabaseObject {
        DatabaseObject(kind: .table, name: name, schema: nil)
    }

    @Test("旧表的慢 COUNT 晚到时不得覆盖新表的行数（回归 #565）")
    func staleCountFromPreviousTableDoesNotPolluteNewTable() async {
        let (viewModel, connection) = await makeSUT(counts: ["table_alpha": 999, "table_beta": 20])
        let tableA = table("table_alpha")
        let tableB = table("table_beta")

        // 打开 A，挂起 A 的后台 COUNT。
        viewModel.openTableObject = tableA
        await connection.armCountGate(table: "table_alpha")
        let slowCount = Task { await viewModel.refreshTableRowCount() }
        await connection.waitUntilCountGateStarts()

        // A 的 COUNT 仍挂起时切到 B（openObject 会把行数重置为 nil），B 自己的 COUNT 立即返回 20。
        viewModel.openTableObject = tableB
        viewModel.tableRowCount = nil
        await viewModel.refreshTableRowCount()
        #expect(viewModel.tableRowCount == 20)

        // 放行 A 的晚到 COUNT（999）：它属于旧表，必须被丢弃，不得污染 B。
        await connection.releaseCountGate()
        await slowCount.value

        #expect(viewModel.openTableObject?.id == tableB.id)
        #expect(viewModel.tableRowCount == 20)
    }

    @Test("当前表自己的 COUNT 正常写回行数")
    func currentTableCountIsWritten() async {
        let (viewModel, _) = await makeSUT(counts: ["table_alpha": 999, "table_beta": 20])

        viewModel.openTableObject = table("table_beta")
        viewModel.tableRowCount = nil
        await viewModel.refreshTableRowCount()

        #expect(viewModel.tableRowCount == 20)
    }
}