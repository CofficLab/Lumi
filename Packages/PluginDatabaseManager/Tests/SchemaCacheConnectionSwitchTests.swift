@testable import DatabaseManagerPlugin
import Foundation
import Testing

/// 回归 #558：切换数据库连接时必须清掉「旧连接」的结构缓存。
///
/// `DatabaseViewModel.connect` 捕获了 `previousConfigId`，却把新 `config.id` 传给
/// `schemaCache.invalidate`，结果新连接刚预加载的缓存被清（随后 refreshSidebarObjects
/// 以 refresh:true 重建），而旧连接的 objects/databases/schemas 缓存永久残留——编辑旧连接
/// 后重连仍命中过期元数据。修复后改为 invalidate(previousConfigId)。
private actor SwitchStubConnection: DatabaseConnection {
    private let databases: [String]
    private let schemas: [String]

    init(databases: [String], schemas: [String]) {
        self.databases = databases
        self.schemas = schemas
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        if sql.contains("pg_database") {
            return QueryResult(columns: ["datname"], rows: databases.map { [.string($0)] }, rowsAffected: 0)
        }
        if sql.contains("information_schema.schemata") {
            return QueryResult(columns: ["schema_name"], rows: schemas.map { [.string($0)] }, rowsAffected: 0)
        }
        return QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
    func beginTransaction() async throws -> any DatabaseTransaction { SwitchStubTransaction() }
    func close() async {}
    func isAlive() async -> Bool { true }
    func isClosed() -> Bool { false }
}

private struct SwitchStubTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}

private actor SwitchStubDriver: DatabaseDriver {
    nonisolated let type: DatabaseType
    private let connection: SwitchStubConnection

    init(type: DatabaseType, connection: SwitchStubConnection) {
        self.type = type
        self.connection = connection
    }

    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection { connection }
}

@MainActor
@Suite(.serialized)
struct SchemaCacheConnectionSwitchTests {

    private func makeSUT() async -> (viewModel: DatabaseViewModel, connection: SwitchStubConnection) {
        let manager = DatabaseManagerCore()
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        let connection = SwitchStubConnection(databases: ["app_db", "analytics"], schemas: ["public", "reporting"])
        let driver = SwitchStubDriver(type: .postgresql, connection: connection)
        await manager.register(driver: driver)
        let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: manager)
        return (viewModel, connection)
    }

    private func config(_ database: String) -> DatabaseConfig {
        DatabaseConfig(name: database, type: .postgresql, database: database)
    }

    @Test("切换连接清掉旧连接的对象缓存，保留新连接的对象缓存（**回归 #558**）")
    func switchInvalidatesPreviousObjectCache() async {
        let (viewModel, _) = await makeSUT()
        let configA = config("db-a")
        let configB = config("db-b")

        await viewModel.connect(config: configA)
        #expect(viewModel.schemaCache.objectsByKey.keys.contains { $0.configId == configA.id })

        await viewModel.connect(config: configB)
        #expect(
            !viewModel.schemaCache.objectsByKey.keys.contains { $0.configId == configA.id },
            "旧连接 A 的对象缓存必须被清掉"
        )
        #expect(
            viewModel.schemaCache.objectsByKey.keys.contains { $0.configId == configB.id },
            "新连接 B 的对象缓存必须保留"
        )
    }

    @Test("切换连接清掉旧连接的数据库列表与 schema 缓存（**回归 #558**）")
    func switchInvalidatesPreviousDatabaseAndSchemaCache() async throws {
        let (viewModel, connection) = await makeSUT()
        let configA = config("db-a")
        let configB = config("db-b")

        await viewModel.connect(config: configA)
        _ = try await viewModel.schemaCache.loadDatabases(for: configA, connection: connection)
        _ = try await viewModel.schemaCache.loadSchemas(for: configA, database: "app_db", connection: connection)
        #expect(viewModel.schemaCache.databasesByConfig[configA.id] != nil)
        #expect(viewModel.schemaCache.schemasByConfig[configA.id] != nil)

        await viewModel.connect(config: configB)
        #expect(
            viewModel.schemaCache.databasesByConfig[configA.id] == nil,
            "旧连接 A 的数据库列表缓存必须被清掉"
        )
        #expect(
            viewModel.schemaCache.schemasByConfig[configA.id] == nil,
            "旧连接 A 的 schema 缓存必须被清掉"
        )
    }

    @Test("首次连接没有旧连接，新连接缓存照常建立")
    func firstConnectKeepsNewObjectCache() async {
        let (viewModel, _) = await makeSUT()
        let configA = config("db-a")

        await viewModel.connect(config: configA)
        #expect(viewModel.schemaCache.objectsByKey.keys.contains { $0.configId == configA.id })
    }

    @Test("重连同一配置仍清掉其旧缓存，避免编辑后命中过期元数据")
    func reconnectSameConfigRefreshesCache() async throws {
        let (viewModel, connection) = await makeSUT()
        let configA = config("db-a")

        await viewModel.connect(config: configA)
        _ = try await viewModel.schemaCache.loadDatabases(for: configA, connection: connection)
        #expect(viewModel.schemaCache.databasesByConfig[configA.id] != nil)

        // 同一配置再次连接：previousConfigId == config.id，仍应清掉旧缓存。
        await viewModel.connect(config: configA)
        #expect(
            viewModel.schemaCache.databasesByConfig[configA.id] == nil,
            "重连同一配置时其旧数据库缓存应被清掉"
        )
    }
}