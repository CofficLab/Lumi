import Testing
import DatabaseKit
@testable import PluginDatabaseManager

@MainActor
@Test func demoSQLiteConnectionLoadsDemoTables() async throws {
    let viewModel = DatabaseViewModel()
    let demoConfig = try #require(viewModel.configs.first { $0.name == "Demo SQLite" })

    await viewModel.connect(config: demoConfig)

    #expect(viewModel.isConnected)
    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.sqliteTables.contains("users"))
}

@MainActor
@Test func failedConnectionKeepsPreviousConnectionUsable() async throws {
    let viewModel = DatabaseViewModel()
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
    let viewModel = DatabaseViewModel()
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
