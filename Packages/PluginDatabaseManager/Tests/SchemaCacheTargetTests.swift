@testable import DatabaseManagerPlugin
import Foundation
import Testing

/// 假 PG 连接：按 SQL 区分数据库列表与 schema 列表查询，返回固定行，并记录所有下发的 SQL。
private actor SchemaStubConnection: DatabaseConnection {
    private let databases: [String]
    private let schemas: [String]
    private var issuedQueries: [String] = []

    init(databases: [String], schemas: [String]) {
        self.databases = databases
        self.schemas = schemas
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        issuedQueries.append(sql)
        if sql.contains("pg_database") {
            return QueryResult(columns: ["datname"], rows: databases.map { [.string($0)] }, rowsAffected: 0)
        }
        if sql.contains("information_schema.schemata") {
            return QueryResult(columns: ["schema_name"], rows: schemas.map { [.string($0)] }, rowsAffected: 0)
        }
        return QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }

    func beginTransaction() async throws -> any DatabaseTransaction { StubTransaction() }

    func close() async {}

    func isAlive() async -> Bool { true }

    func databaseQueryCount() -> Int {
        issuedQueries.filter { $0.contains("pg_database") }.count
    }
}

private struct StubTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}

@MainActor
@Suite struct SchemaCacheTargetTests {
    private func makeConfig() -> DatabaseConfig {
        DatabaseConfig(name: "pg", type: .postgresql, database: "app_db")
    }

    private func makeConnection() -> SchemaStubConnection {
        SchemaStubConnection(databases: ["app_db", "analytics"], schemas: ["public", "reporting"])
    }

    @Test("加载 schema 不得覆盖数据库缓存（回归 #559）")
    func loadSchemasDoesNotOverwriteDatabaseCache() async throws {
        let service = SchemaCacheService()
        let config = makeConfig()
        let connection = makeConnection()

        let firstDatabases = try await service.loadDatabases(for: config, connection: connection)
        #expect(firstDatabases == ["app_db", "analytics"])

        let schemas = try await service.loadSchemas(for: config, database: "app_db", connection: connection)
        #expect(schemas == ["public", "reporting"])

        let secondDatabases = try await service.loadDatabases(for: config, connection: connection)
        #expect(secondDatabases == ["app_db", "analytics"])
        #expect(service.databasesByConfig[config.id] == ["app_db", "analytics"])
    }

    @Test("加载 schema 必须写入 schema 缓存而非数据库缓存（回归 #559）")
    func loadSchemasPopulatesSchemaCache() async throws {
        let service = SchemaCacheService()
        let config = makeConfig()
        let connection = makeConnection()

        let schemas = try await service.loadSchemas(for: config, database: "app_db", connection: connection)
        #expect(schemas == ["public", "reporting"])
        #expect(service.schemasByConfig[config.id] == ["public", "reporting"])
        #expect(service.databasesByConfig[config.id] == nil)
    }

    @Test("加载数据库只写数据库缓存，不碰 schema 缓存（回归 #559）")
    func loadDatabasesPopulatesDatabaseCacheOnly() async throws {
        let service = SchemaCacheService()
        let config = makeConfig()
        let connection = makeConnection()

        let databases = try await service.loadDatabases(for: config, connection: connection)
        #expect(databases == ["app_db", "analytics"])
        #expect(service.databasesByConfig[config.id] == ["app_db", "analytics"])
        #expect(service.schemasByConfig[config.id] == nil)
    }

    @Test("schema 加载后数据库缓存命中不得重新查询（回归 #559）")
    func databaseCacheHitDoesNotRequeryAfterSchemaLoad() async throws {
        let service = SchemaCacheService()
        let config = makeConfig()
        let connection = makeConnection()

        _ = try await service.loadDatabases(for: config, connection: connection)
        _ = try await service.loadSchemas(for: config, database: "app_db", connection: connection)
        _ = try await service.loadDatabases(for: config, connection: connection)

        let count = await connection.databaseQueryCount()
        #expect(count == 1)
    }
}