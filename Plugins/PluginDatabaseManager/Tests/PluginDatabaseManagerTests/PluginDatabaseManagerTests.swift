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
