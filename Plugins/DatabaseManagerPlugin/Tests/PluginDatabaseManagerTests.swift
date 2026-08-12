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
@Test func openObjectOpensTableBrowserForMySQL() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    // 构造一个已选中的 MySQL 上下文（不实际联网）。
    let config = DatabaseConfig(name: "MySQL", type: .mysql, host: "h", port: 3306, database: "db", username: "u")
    viewModel.configs = [config]
    viewModel.selectedConfig = config
    let object = DatabaseObject(kind: .table, name: "users", database: "db")
    await viewModel.openObject(object)
    // openObject 进入分页浏览主区，重置到第 0 页
    #expect(viewModel.openTableObject?.name == "users")
    #expect(viewModel.tablePage == 0)
    #expect(viewModel.tablePageSize == 100)
    DatabaseConnectionStore.resetSavedConfigs()
}

@Test func qualifiedNameQualifiesByDatabaseOrSchema() {
    let mysqlTable = DatabaseObject(kind: .table, name: "users", database: "shop")
    #expect(DatabaseViewModel.qualifiedName(for: mysqlTable, type: .mysql) == "`shop`.`users`")

    let pgTable = DatabaseObject(kind: .table, name: "users", database: "app", schema: "public")
    #expect(DatabaseViewModel.qualifiedName(for: pgTable, type: .postgresql) == "\"public\".\"users\"")

    let sqliteTable = DatabaseObject(kind: .table, name: "users")
    #expect(DatabaseViewModel.qualifiedName(for: sqliteTable, type: .sqlite) == "\"users\"")
}

@MainActor
@Test func toggleSortCyclesAscendingDescendingOff() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)
    let users = DatabaseObject(kind: .table, name: "users")
    await viewModel.openObject(users)
    // 打开后已加载首页
    #expect(viewModel.queryResult != nil)
    #expect(viewModel.openTableObject?.name == "users")

    // 无 → 升序
    await viewModel.toggleSort(column: "name")
    #expect(viewModel.tableOrderBy?.column == "name")
    #expect(viewModel.tableOrderBy?.ascending == true)

    // 升序 → 降序
    await viewModel.toggleSort(column: "name")
    #expect(viewModel.tableOrderBy?.ascending == false)

    // 降序 → 关闭
    await viewModel.toggleSort(column: "name")
    #expect(viewModel.tableOrderBy?.column == nil)
}

// MARK: - Change tracking

@MainActor
private func makeUsersSchema() -> TableSchema {
    TableSchema(
        table: DatabaseObject(kind: .table, name: "users", database: "app"),
        columns: [
            TableColumn(name: "id", dataType: "INTEGER", isNullable: false, isPrimaryKey: true, defaultValue: nil, position: 0),
            TableColumn(name: "name", dataType: "TEXT", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 1),
            TableColumn(name: "email", dataType: "TEXT", isNullable: true, isPrimaryKey: false, defaultValue: nil, position: 2),
        ]
    )
}

@MainActor
@Test func changeManagerGeneratesUpdateWithPrimaryKeyWhere() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    #expect(manager.isEditable)

    let columns = ["id", "name", "email"]
    let row: [DatabaseValue] = [.integer(7), .string("Alice"), .string("a@x.com")]
    manager.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row, columns: columns)

    #expect(manager.hasChanges)
    #expect(manager.changedCellCount == 1)
    let sql = manager.generatedUpdateStatements(for: .postgresql)
    // PG 按 schema 限定；该对象无 schema → 仅表名
    #expect(sql == ["UPDATE \"users\" SET \"name\" = 'Bob' WHERE \"id\" = 7;"])
}

@MainActor
@Test func changeManagerCoalescesMultipleColumnsPerRow() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    let columns = ["id", "name", "email"]
    let row: [DatabaseValue] = [.integer(7), .string("Alice"), .string("a@x.com")]
    manager.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row, columns: columns)
    manager.stageCellUpdate(column: "email", newValue: .string("b@x.com"), rowValues: row, columns: columns)

    let sql = manager.generatedUpdateStatements(for: .postgresql)
    #expect(sql.count == 1)  // 同行多列合并为一条 UPDATE
    #expect(sql.first?.contains("\"name\" = 'Bob'") == true)
    #expect(sql.first?.contains("\"email\" = 'b@x.com'") == true)
    #expect(manager.changedCellCount == 2)
}

@MainActor
@Test func changeManagerRevertsWhenValueMatchesOriginal() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    let columns = ["id", "name", "email"]
    let row: [DatabaseValue] = [.integer(7), .string("Alice"), .null]
    manager.stageCellUpdate(column: "name", newValue: .string("Bob"), rowValues: row, columns: columns)
    #expect(manager.hasChanges)

    // 改回原值 → 变更被移除
    manager.stageCellUpdate(column: "name", newValue: .string("Alice"), rowValues: row, columns: columns)
    #expect(!manager.hasChanges)
    #expect(manager.generatedUpdateStatements(for: .sqlite).isEmpty)
}

@MainActor
@Test func changeManagerEscapesSingleQuotesInValues() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    let columns = ["id", "name", "email"]
    let row: [DatabaseValue] = [.integer(1), .string("old"), .null]
    manager.stageCellUpdate(column: "name", newValue: .string("O'Brien"), rowValues: row, columns: columns)
    let sql = manager.generatedUpdateStatements(for: .sqlite).first
    #expect(sql == "UPDATE \"users\" SET \"name\" = 'O''Brien' WHERE \"id\" = 1;")
}

@MainActor
@Test func changeManagerRequiresPrimaryKey() throws {
    var schema = makeUsersSchema()
    // 去掉主键
    schema = TableSchema(
        table: schema.table,
        columns: schema.columns.map { TableColumn(name: $0.name, dataType: $0.dataType, isNullable: $0.isNullable, isPrimaryKey: false, defaultValue: $0.defaultValue, position: $0.position) }
    )
    let manager = TableChangeManager(table: schema.table, schema: schema)
    #expect(!manager.isEditable)
    // 无主键：stage 是 no-op，不产生 SQL
    manager.stageCellUpdate(column: "name", newValue: .string("x"), rowValues: [.integer(1), .string("a"), .null], columns: ["id", "name", "email"])
    #expect(!manager.hasChanges)
}

@MainActor
@Test func changeManagerGeneratesInsertWithSetColumns() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    let id = manager.addInsert()
    manager.setInsertColumn(insertId: id, column: "name", value: .string("Carol"))
    manager.setInsertColumn(insertId: id, column: "email", value: .string("c@x.com"))

    let sql = manager.generatedInsertStatements(for: .sqlite)
    #expect(sql.count == 1)
    // 列按表结构顺序输出（id, name, email）；id 未设故不在 INSERT 列表
    #expect(sql.first == "INSERT INTO \"users\" (\"name\", \"email\") VALUES ('Carol', 'c@x.com');")
}

@MainActor
@Test func changeManagerEmptyInsertUsesDefaultValues() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    _ = manager.addInsert()
    let sqlite = manager.generatedInsertStatements(for: .sqlite).first
    #expect(sqlite == "INSERT INTO \"users\" DEFAULT VALUES;")
    let mysql = manager.generatedInsertStatements(for: .mysql).first
    #expect(mysql == "INSERT INTO `app`.`users` () VALUES ();")
}

@MainActor
@Test func changeManagerGeneratesDeleteWithPrimaryKeyWhere() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    let columns = ["id", "name", "email"]
    let row: [DatabaseValue] = [.integer(9), .string("Dan"), .null]
    manager.toggleRowDeletion(rowValues: row, columns: columns)

    #expect(manager.pendingDeleteCount == 1)
    let sql = manager.generatedDeleteStatements(for: .sqlite)
    #expect(sql == ["DELETE FROM \"users\" WHERE \"id\" = 9;"])
    // 删除后该行不应再产生 UPDATE
    manager.stageCellUpdate(column: "name", newValue: .string("x"), rowValues: row, columns: columns)
    #expect(manager.generatedUpdateStatements(for: .sqlite).isEmpty)
}

@MainActor
@Test func changeManagerUndoRedoRestoresState() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    let columns = ["id", "name", "email"]
    let row: [DatabaseValue] = [.integer(1), .string("old"), .null]
    manager.stageCellUpdate(column: "name", newValue: .string("new"), rowValues: row, columns: columns)
    #expect(manager.hasChanges)
    #expect(manager.canUndo)
    #expect(!manager.canRedo)

    manager.undo()
    #expect(!manager.hasChanges)  // 撤销后回到无变更
    #expect(manager.canRedo)

    manager.redo()
    #expect(manager.hasChanges)  // 重做恢复变更
    #expect(manager.changedCellCount == 1)
}

@MainActor
@Test func changeManagerUndoRevertsInsertAndDelete() throws {
    let manager = TableChangeManager(table: makeUsersSchema().table, schema: makeUsersSchema())
    _ = manager.addInsert()
    manager.toggleRowDeletion(rowValues: [.integer(5), .string("a"), .null], columns: ["id", "name", "email"])
    #expect(manager.pendingInsertCount == 1)
    #expect(manager.pendingDeleteCount == 1)

    manager.undo()  // 撤销删除
    #expect(manager.pendingDeleteCount == 0)
    #expect(manager.pendingInsertCount == 1)

    manager.undo()  // 撤销新增
    #expect(manager.pendingInsertCount == 0)
}


@Test func parseEditedTextMapsCommonLiteralForms() {
    #expect(parseEditedCellValue("") == .null)
    #expect(parseEditedCellValue("NULL") == .null)
    #expect(parseEditedCellValue("42") == .integer(42))
    #expect(parseEditedCellValue("3.14") == .double(3.14))
    #expect(parseEditedCellValue("true") == .bool(true))
    #expect(parseEditedCellValue("FALSE") == .bool(false))
    #expect(parseEditedCellValue("Alice") == .string("Alice"))
}

@MainActor
@Test func editingStageAndSavePersistsChange() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)

    let users = DatabaseObject(kind: .table, name: "users")
    await viewModel.openObject(users)
    // demo users 表有主键 id，应可编辑
    let cm = try #require(viewModel.changeManager)
    #expect(cm.isEditable)

    // 找到 Alice 行，修改其 name
    let result = try #require(viewModel.queryResult)
    let columns = result.columns
    guard let aliceRow = result.rows.first(where: { row in
        columns.firstIndex(of: "name").map { idx in
            if case .string(let s) = row[idx] { return s == "Alice" }
            return false
        } ?? false
    }) else {
        Issue.record("demo should contain Alice")
        return
    }
    viewModel.stageCellChange(column: "name", newValue: .string("Alicia"), rowValues: aliceRow, columns: columns)
    #expect(viewModel.changeManager?.hasChanges == true)
    #expect(viewModel.pendingChangeSQL.contains { $0.contains("'Alicia'") })

    await viewModel.saveChanges()
    #expect(viewModel.changeManager?.hasChanges == false)

    // 验证已落库
    guard let conn = await DatabaseManagerCore.shared.getConnection(for: demoConfig.id) else {
        Issue.record("connection lost")
        return
    }
    let check = try await conn.query("SELECT name FROM users WHERE id = 1;", params: nil)
    #expect(check.rows.first?.first == .string("Alicia"))
}

@MainActor
@Test func insertRowSavePersistsNewRow() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)
    let users = DatabaseObject(kind: .table, name: "users")
    await viewModel.openObject(users)

    let insertId = try #require(viewModel.addRow())
    viewModel.stageInsertCell(insertId: insertId, column: "name", value: .string("Zoe"))
    viewModel.stageInsertCell(insertId: insertId, column: "email", value: .string("zoe@x.com"))
    #expect(viewModel.changeManager?.pendingInsertCount == 1)

    await viewModel.saveChanges()
    #expect(viewModel.changeManager?.hasChanges == false)

    guard let conn = await DatabaseManagerCore.shared.getConnection(for: demoConfig.id) else {
        Issue.record("connection lost")
        return
    }
    let check = try await conn.query("SELECT name FROM users WHERE email = 'zoe@x.com';", params: nil)
    #expect(check.rows.first?.first == .string("Zoe"))
}

@MainActor
@Test func deleteRowSaveRemovesRow() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)
    let users = DatabaseObject(kind: .table, name: "users")
    await viewModel.openObject(users)

    let result = try #require(viewModel.queryResult)
    let columns = result.columns
    guard let bobRow = result.rows.first(where: { row in
        guard let idx = columns.firstIndex(of: "name") else { return false }
        if case .string(let s) = row[idx] { return s == "Bob" }
        return false
    }) else {
        Issue.record("demo should contain Bob")
        return
    }
    viewModel.toggleRowDeletion(rowValues: bobRow, columns: columns)
    #expect(viewModel.changeManager?.pendingDeleteCount == 1)

    await viewModel.saveChanges()

    guard let conn = await DatabaseManagerCore.shared.getConnection(for: demoConfig.id) else {
        Issue.record("connection lost")
        return
    }
    let check = try await conn.query("SELECT COUNT(*) AS c FROM users;", params: nil)
    // 初始 2 行（Alice、Bob），删 Bob 后剩 1 行
    #expect(check.rows.first?.first == .integer(1))
}

@MainActor
@Test func viewModelUndoRedoThroughChangeManager() async throws {
    let viewModel = DatabaseViewModel(loadSavedConfigs: false)
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })
    await viewModel.connect(config: demoConfig)
    let users = DatabaseObject(kind: .table, name: "users")
    await viewModel.openObject(users)

    viewModel.addRow()
    #expect(viewModel.changeManager?.pendingInsertCount == 1)
    viewModel.undoChange()
    #expect(viewModel.changeManager?.pendingInsertCount == 0)
    viewModel.redoChange()
    #expect(viewModel.changeManager?.pendingInsertCount == 1)
}







