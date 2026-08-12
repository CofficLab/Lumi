import Foundation
import Testing
@testable import DatabaseManagerPlugin

@MainActor
@Test func demoSQLiteConnectionLoadsDemoTables() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })

    await viewModel.connect(config: demoConfig)

    #expect(viewModel.isConnected)
    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.sqliteTables.contains("users"))
}

@MainActor
@Test func failedConnectionKeepsPreviousConnectionUsable() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)

    let brokenConfig = DatabaseConfig(
        name: "Broken SQLite",
        type: .sqlite,
        database: ""
    )

    await viewModel.connect(config: brokenConfig)
    viewModel.queryText = "SELECT COUNT(*) AS count FROM users;"
    await viewModel.executeQuery()

    #expect(viewModel.selectedConfig?.id == demoConfig.id)
    #expect(viewModel.isConnected)
    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.queryResult?.rows == [[.integer(2)]])
}

@Test func connectionDraftTrimsPersistedNetworkConfig() throws {
    let config = try DatabaseConnectionDraft(
        name: "  Local Postgres  ",
        type: .postgresql,
        host: "  localhost  ",
        portText: " 5432 ",
        database: " postgres ",
        username: " user ",
        password: "secret",
        sqlitePath: ""
    ).makeConfig()

    #expect(config.name == "Local Postgres")
    #expect(config.host == "localhost")
    #expect(config.port == 5432)
    #expect(config.database == "postgres")
    #expect(config.username == "user")
    #expect(config.password == "secret")
}

@Test func connectionDraftRejectsWhitespaceOnlyRequiredFields() {
    #expect(throws: DatabaseConnectionDraftError.self) {
        try DatabaseConnectionDraft(
            name: "   ",
            type: .redis,
            host: "localhost",
            portText: "6379",
            database: "",
            username: "",
            password: "",
            sqlitePath: ""
        ).makeConfig()
    }

    #expect(throws: DatabaseConnectionDraftError.self) {
        try DatabaseConnectionDraft(
            name: "Redis",
            type: .redis,
            host: "   ",
            portText: "6379",
            database: "",
            username: "",
            password: "",
            sqlitePath: ""
        ).makeConfig()
    }
}

@Test func connectionDraftRejectsInvalidPortBeforeConnecting() {
    #expect(throws: DatabaseConnectionDraftError.self) {
        try DatabaseConnectionDraft(
            name: "Redis",
            type: .redis,
            host: "localhost",
            portText: "70000",
            database: "",
            username: "",
            password: "",
            sqlitePath: ""
        ).makeConfig()
    }
}

@Test func connectionDraftAllowsDefaultNameForTestingOnly() throws {
    let config = try DatabaseConnectionDraft(
        name: "",
        type: .redis,
        host: "localhost",
        portText: "6379",
        database: "",
        username: "",
        password: "",
        sqlitePath: ""
    ).makeConfig(defaultName: "Test")

    #expect(config.name == "Test")
    #expect(config.port == 6379)
}

@MainActor
@Test func openSQLiteTableEscapesQuotedTableNames() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)

    viewModel.queryText = "CREATE TABLE \"quoted\"\"table\" (id INTEGER);"
    await viewModel.executeQuery()
    await viewModel.loadSQLiteTables()

    #expect(viewModel.sqliteTables.contains("quoted\"table"))

    await viewModel.openSQLiteTable("quoted\"table")

    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.queryText == "SELECT * FROM \"quoted\"\"table\" LIMIT 50;")
    #expect(viewModel.queryResult?.columns == ["id"])
}

// MARK: - Capabilities

@Test func capabilitiesPresetsMatchEngineCharacteristics() {
    // SQLite：本地文件，无 SSL/多库/schema
    let sqlite = DatabaseType.sqlite.capabilities
    #expect(sqlite.supportsSchemaEditing)
    #expect(sqlite.supportsViews)
    #expect(!sqlite.supportsSSL)
    #expect(!sqlite.supportsMultipleDatabases)
    #expect(sqlite.identifierQuoteCharacter == "\"")
    #expect(sqlite.defaultQueryLimit == 50)

    // MySQL：网络库，支持 SSL/多库/例程，反引号引用
    let mysql = DatabaseType.mysql.capabilities
    #expect(mysql.supportsSSL)
    #expect(mysql.supportsRoutines)
    #expect(mysql.supportsMultipleDatabases)
    #expect(mysql.identifierQuoteCharacter == "`")

    // PostgreSQL：唯一支持 schema 命名空间和物化视图
    let pg = DatabaseType.postgresql.capabilities
    #expect(pg.supportsSchemas)
    #expect(pg.supportsMaterializedViews)

    // Redis：无关系型结构，无 EXPLAIN
    let redis = DatabaseType.redis.capabilities
    #expect(!redis.supportsSchemaEditing)
    #expect(!redis.supportsExplain)
    #expect(redis.identifierQuoteCharacter == nil)
}

@Test func defaultPortsAreConventional() {
    #expect(DatabaseType.mysql.defaultPort == 3306)
    #expect(DatabaseType.postgresql.defaultPort == 5432)
    #expect(DatabaseType.redis.defaultPort == 6379)
    #expect(DatabaseType.sqlite.defaultPort == nil)
}

// MARK: - SQLite introspection

@MainActor
@Test func sqliteIntrospectorListsTablesAndDescribesColumns() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)

    let connection = try #require(await DatabaseManagerCore.shared.getConnection(for: demoConfig.id))
    let introspector = DatabaseType.sqlite.introspector

    let tables = try await introspector.loadObjects(of: .table, in: connection, database: nil, schema: nil)
    #expect(tables.contains { $0.name == "users" })

    let usersObject = try #require(tables.first { $0.name == "users" })
    let schema = try await introspector.describeTable(usersObject, in: connection)
    #expect(schema.columns.contains { $0.name == "name" })
    let idColumn = try #require(schema.columns.first { $0.name == "id" })
    #expect(idColumn.isPrimaryKey)
    #expect(idColumn.dataType.uppercased().contains("INT"))
    #expect(schema.ddl?.contains("CREATE TABLE") == true)
}

// MARK: - Connection pool

/// 验证连接池：release 后再 acquire 应复用同一个连接（文件型 SQLite，非 :memory:）。
@Test func connectionPoolReusesIdleConnections() async throws {
    let manager = DatabaseManagerCore()
    await manager.register(driver: SQLiteDriver())

    let path = NSTemporaryDirectory() + "lumi_pool_\(UUID().uuidString).sqlite"
    defer { try? FileManager.default.removeItem(atPath: path) }
    let config = DatabaseConfig(name: "PoolTest", type: .sqlite, database: path)

    let first = try await manager.acquireConnection(for: config)
    await manager.releaseConnection(first, for: config)
    let second = try await manager.acquireConnection(for: config)

    // 复用：两个引用指向同一个连接实例
    #expect(ObjectIdentifier(first as AnyObject) == ObjectIdentifier(second as AnyObject))

    await manager.releaseConnection(second, for: config)
    await manager.shutdown()
}

/// 验证 `withConnection` 在闭包正常返回后归还连接，可被下一次调用复用。
@Test func withConnectionReleasesConnectionOnSuccess() async throws {
    let manager = DatabaseManagerCore()
    await manager.register(driver: SQLiteDriver())

    let path = NSTemporaryDirectory() + "lumi_with_\(UUID().uuidString).sqlite"
    defer { try? FileManager.default.removeItem(atPath: path) }
    let config = DatabaseConfig(name: "WithTest", type: .sqlite, database: path)

    let used = try await manager.withConnection(for: config) { connection -> ObjectIdentifier in
        // 建表确认连接可用
        _ = try await connection.execute("CREATE TABLE t (id INTEGER)", params: nil)
        return ObjectIdentifier(connection as AnyObject)
    }

    // withConnection 归还后，再次借出应复用同一连接
    let again = try await manager.acquireConnection(for: config)
    #expect(ObjectIdentifier(again as AnyObject) == used)
    await manager.releaseConnection(again, for: config)
    await manager.shutdown()
}

// MARK: - Schema cache

@MainActor
@Test func schemaCacheServesCachedObjectsAndInvalidates() async throws {
    let cache = SchemaCacheService()
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)
    let connection = try #require(await DatabaseManagerCore.shared.getConnection(for: demoConfig.id))

    let first = try await cache.objects(
        for: demoConfig, kind: .table, database: nil, schema: nil, connection: connection
    )
    #expect(first.contains { $0.name == "users" })
    // 第二次读取命中缓存（无异常即通过）
    let second = try await cache.objects(
        for: demoConfig, kind: .table, database: nil, schema: nil, connection: connection
    )
    #expect(second.count == first.count)

    // invalidate 后应清空该连接缓存
    cache.invalidate(configId: demoConfig.id)
    #expect(cache.objectsByKey.isEmpty)
}

// MARK: - SSL option

@Test func sslOptionRoundTripsThroughConfigOptions() throws {
    var config = DatabaseConfig(name: "PG", type: .postgresql, database: "app")
    #expect(config.sslOption == nil)

    config = config.withSSLOption(.require)
    #expect(config.sslOption == .require)
    #expect(config.options?["ssl"] == "require")

    // nil 移除选项，options 清空回 nil
    config = config.withSSLOption(nil)
    #expect(config.sslOption == nil)
    #expect(config.options == nil)
}

// MARK: - Connection editing

@MainActor
@Test func updateConfigPreservesPasswordWhenLeftBlank() async throws {
    // 直接设置 configs，绕过 addConfig，避免把 demo :memory: 配置持久化到
    // 进程级 UserDefaults（会污染并行执行的其它测试）。
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let original = DatabaseConfig(
        name: "Edit Me",
        type: .postgresql,
        host: "localhost",
        port: 5432,
        database: "app",
        username: "u",
        password: "secret"
    )
    viewModel.configs = [original]

    // 模拟表单：改名、密码留空
    var edited = original
    edited.name = "Edit Me 2"
    edited.password = ""
    viewModel.updateConfig(edited)

    let stored = try #require(viewModel.configs.first { $0.id == original.id })
    #expect(stored.name == "Edit Me 2")
    #expect(stored.password == "secret")  // 沿用旧密码

    DatabaseConnectionStore.resetSavedConfigs()
}

// MARK: - Identifier quoting & unified open

@Test func quoteIdentifierUsesDialectQuoteCharacter() {
    // SQLite / PostgreSQL：双引号
    #expect(DatabaseViewModel.quoteIdentifier("users", for: .sqlite) == "\"users\"")
    #expect(DatabaseViewModel.quoteIdentifier("users", for: .postgresql) == "\"users\"")
    // MySQL：反引号
    #expect(DatabaseViewModel.quoteIdentifier("users", for: .mysql) == "`users`")
    // Redis：无引用字符，原样返回
    #expect(DatabaseViewModel.quoteIdentifier("user:1", for: .redis) == "user:1")
}

@Test func quoteIdentifierEscapesEmbeddedQuote() {
    #expect(DatabaseViewModel.quoteIdentifier("quoted\"table", for: .sqlite) == "\"quoted\"\"table\"")
    #expect(DatabaseViewModel.quoteIdentifier("order`desc", for: .mysql) == "`order``desc`")
}

@MainActor
@Test func openObjectBuildsLimitedSelectForMySQL() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    // 构造一个已选中的 MySQL 上下文（不实际联网，仅验证查询构造）。
    let config = DatabaseConfig(name: "MySQL", type: .mysql, host: "h", port: 3306, database: "db", username: "u")
    viewModel.configs = [config]
    viewModel.selectedConfig = config
    // openObject 会尝试执行并失败（无连接），但 queryText 应已被设置。
    let object = DatabaseObject(kind: .table, name: "users", database: "db")
    await viewModel.openObject(object)
    #expect(viewModel.queryText == "SELECT * FROM `users` LIMIT 100;")
    DatabaseConnectionStore.resetSavedConfigs()
}




