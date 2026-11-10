@testable import DatabaseManagerPlugin
import Foundation
import Testing

/// 用于标记「慢查询」的 SQL 片段：只有包含它的查询会被假连接挂起。
private let slowQueryToken = "lumi_slow_query"

/// 可控延迟的假连接：普通查询立即返回，慢查询挂起直到测试显式放行。
private actor ControlledConnection: DatabaseConnection {
    private let label: String
    private var slowQueryStarted = false
    private var slowQueryContinuation: CheckedContinuation<Void, Never>?
    private var slowQueryReleased = false
    private var closeCount = 0
    /// 让下一次查询挂起（用于精确卡住「表列表」这类固定 SQL）。
    private var blockNextQuery = false

    init(label: String) {
        self.label = label
    }

    func armNextQueryBlock() {
        blockNextQuery = true
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        if sql.contains(slowQueryToken) || blockNextQuery {
            blockNextQuery = false
            slowQueryStarted = true
            await withCheckedContinuation { continuation in
                if slowQueryReleased {
                    continuation.resume()
                } else {
                    slowQueryContinuation = continuation
                }
            }
            return QueryResult(columns: ["source"], rows: [[.string(label)]], rowsAffected: 1)
        }
        return QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        0
    }

    func beginTransaction() async throws -> any DatabaseTransaction {
        TestTransaction()
    }

    func close() async {
        closeCount += 1
    }

    func isAlive() async -> Bool {
        true
    }

    func isClosed() -> Bool {
        closeCount > 0
    }

    func waitUntilSlowQueryStarts() async {
        while !slowQueryStarted {
            await Task.yield()
        }
    }

    func releaseSlowQuery() {
        if let continuation = slowQueryContinuation {
            slowQueryContinuation = nil
            continuation.resume()
        } else {
            slowQueryReleased = true
        }
    }
}

private struct TestTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}

/// 可按库名挂起 `connect` 的假驱动，用于复现「旧连接更晚完成」的竞态。
private actor ControlledDriver: DatabaseDriver {
    nonisolated let type: DatabaseType
    private let connections: [String: ControlledConnection]
    private var connectBlocked: Set<String> = []
    private var connectSignaled: Set<String> = []
    private var connectWaiters: [String: CheckedContinuation<Void, Never>] = [:]
    private var connectReleased: Set<String> = []

    init(type: DatabaseType, connections: [String: ControlledConnection]) {
        self.type = type
        self.connections = connections
    }

    func blockNextConnect(database: String) {
        connectBlocked.insert(database)
    }

    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        let database = config.database
        if connectBlocked.remove(database) != nil {
            connectSignaled.insert(database)
            await withCheckedContinuation { continuation in
                if connectReleased.contains(database) {
                    continuation.resume()
                } else {
                    connectWaiters[database] = continuation
                }
            }
        }
        guard let connection = connections[database] else {
            throw DatabaseError.connectionFailed("No fake connection for \(database)")
        }
        return connection
    }

    func waitUntilConnectBlocked(_ database: String) async {
        while !connectSignaled.contains(database) {
            await Task.yield()
        }
    }

    func releaseConnect(_ database: String) {
        connectReleased.insert(database)
        if let waiter = connectWaiters.removeValue(forKey: database) {
            waiter.resume()
        }
    }
}

/// 记录所有 SQL 的假连接，用于验证结构刷新是否真的打到数据库。
private actor QueryCountingConnection: DatabaseConnection {
    private var issuedQueries: [String] = []

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        issuedQueries.append(sql)
        return QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        issuedQueries.append(sql)
        return 0
    }

    func beginTransaction() async throws -> any DatabaseTransaction {
        TestTransaction()
    }

    func close() async {}

    func isAlive() async -> Bool {
        true
    }

    func isClosed() -> Bool {
        false
    }

    func issuedQueryCount() -> Int {
        issuedQueries.count
    }
}

/// 返回固定计数连接的假驱动。
private actor CountingDriver: DatabaseDriver {
    nonisolated let type: DatabaseType
    private let connection: QueryCountingConnection

    init(type: DatabaseType, connection: QueryCountingConnection) {
        self.type = type
        self.connection = connection
    }

    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        connection
    }
}

@MainActor
@Suite struct DatabaseViewModelConnectionRaceTests {
    private func makeSUT() async -> (
        viewModel: DatabaseViewModel,
        driver: ControlledDriver,
        connectionA: ControlledConnection
    ) {
        let manager = DatabaseManagerCore()
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        let connectionA = ControlledConnection(label: "A")
        let connectionB = ControlledConnection(label: "B")
        let driver = ControlledDriver(
            type: .postgresql,
            connections: ["db-a": connectionA, "db-b": connectionB]
        )
        await manager.register(driver: driver)
        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        return (viewModel, driver, connectionA)
    }

    private func config(database: String) -> DatabaseConfig {
        DatabaseConfig(name: database, type: .postgresql, database: database)
    }

    @Test("慢查询返回后不得覆盖已经切换到的连接状态")
    func slowQueryFromPreviousConnectionDoesNotOverwriteNewConnection() async {
        let (viewModel, _, connectionA) = await makeSUT()
        let configA = config(database: "db-a")
        let configB = config(database: "db-b")

        await viewModel.connect(config: configA)
        #expect(viewModel.selectedConfig?.id == configA.id)
        #expect(viewModel.isConnected)

        viewModel.queryText = "SELECT * FROM \(slowQueryToken)"
        let slowQuery = Task { await viewModel.executeQuery() }
        await connectionA.waitUntilSlowQueryStarts()

        // 查询仍挂在旧连接上时切到 B。
        await viewModel.connect(config: configB)
        #expect(viewModel.selectedConfig?.id == configB.id)

        await connectionA.releaseSlowQuery()
        await slowQuery.value

        #expect(viewModel.selectedConfig?.id == configB.id)
        #expect(viewModel.isConnected)
        #expect(viewModel.queryResult == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test("更慢的旧连接完成后不得抢占新选中的连接")
    func slowerConnectDoesNotReplaceNewerSelection() async {
        let (viewModel, driver, connectionA) = await makeSUT()
        let configA = config(database: "db-a")
        let configB = config(database: "db-b")

        await driver.blockNextConnect(database: "db-a")
        let slowConnect = Task { await viewModel.connect(config: configA) }
        await driver.waitUntilConnectBlocked("db-a")

        // B 在 A 尚未连上时先完成。
        await viewModel.connect(config: configB)
        #expect(viewModel.selectedConfig?.id == configB.id)

        await driver.releaseConnect("db-a")
        await slowConnect.value

        #expect(viewModel.selectedConfig?.id == configB.id)
        #expect(viewModel.isConnected)
        #expect(viewModel.isLoading == false)
        let staleConnectionClosed = await connectionA.isClosed()
        #expect(staleConnectionClosed)
    }

    @Test("旧库的表列表晚到时不得覆盖新选中的库")
    func staleSQLiteTablesDoNotOverwriteNewDatabase() async {
        let manager = DatabaseManagerCore()
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        let connectionA = ControlledConnection(label: "table_a")
        let connectionB = ControlledConnection(label: "table_b")
        let driver = ControlledDriver(
            type: .sqlite,
            connections: ["db-a": connectionA, "db-b": connectionB]
        )
        await manager.register(driver: driver)
        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        let configA = DatabaseConfig(name: "db-a", type: .sqlite, database: "db-a")
        let configB = DatabaseConfig(name: "db-b", type: .sqlite, database: "db-b")

        // 卡住 A 的表列表查询，模拟旧库更晚返回。
        await connectionA.armNextQueryBlock()
        let slowConnect = Task { await viewModel.connect(config: configA) }
        await connectionA.waitUntilSlowQueryStarts()

        await viewModel.connect(config: configB)
        #expect(viewModel.selectedConfig?.id == configB.id)

        await connectionA.releaseSlowQuery()
        await slowConnect.value

        // A 的结果属于旧连接，不能写进当前详情页。
        #expect(viewModel.selectedConfig?.id == configB.id)
        #expect(viewModel.sqliteTables.isEmpty)
    }

    @Test("Reload 侧边栏对象树必须绕过缓存重新查询数据库")
    func sidebarReloadBypassesSchemaCache() async {
        let manager = DatabaseManagerCore()
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        let connection = QueryCountingConnection()
        let driver = CountingDriver(type: .postgresql, connection: connection)
        await manager.register(driver: driver)
        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        let config = DatabaseConfig(name: "db-reload", type: .postgresql, database: "db-reload")

        await viewModel.connect(config: config)
        let afterConnect = await connection.issuedQueryCount()

        // 首次连接已经填充过结构缓存，Reload 不能再直接命中缓存。
        await viewModel.refreshSidebarObjects()

        let afterReload = await connection.issuedQueryCount()
        #expect(afterReload > afterConnect)
    }
}
