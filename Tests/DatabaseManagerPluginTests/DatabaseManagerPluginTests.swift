#if canImport(XCTest)
import XCTest
@testable import Lumi

final class DatabaseManagerPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(DatabaseManagerPlugin.id, "DatabaseManager")
        XCTAssertEqual(DatabaseManagerPlugin.navigationId, "database_manager")
        XCTAssertEqual(DatabaseManagerPlugin.iconName, "server.rack")
        XCTAssertFalse(DatabaseManagerPlugin.enable)
        XCTAssertEqual(DatabaseManagerPlugin.order, 50)
    }

    @MainActor
    func testPluginProvidesDatabaseAgentTools() {
        let context = ToolContext(toolService: ToolService(), llmService: nil, llmVM: nil, conversationVM: nil)
        let tools = DatabaseManagerPlugin.shared.agentTools(context: context)
        XCTAssertEqual(
            tools.map(\.name),
            [
                "database_list_connections",
                "database_describe_schema",
                "database_query_readonly",
                "database_sample_table",
            ]
        )
    }

    func testReadonlySQLValidationRejectsMutatingStatements() {
        XCTAssertNoThrow(try DatabaseAgentToolService.readonlySQL("SELECT * FROM users", type: .sqlite, limit: 10))
        XCTAssertThrowsError(try DatabaseAgentToolService.readonlySQL("DELETE FROM users", type: .sqlite, limit: 10))
        XCTAssertThrowsError(try DatabaseAgentToolService.readonlySQL("SELECT * FROM users; DROP TABLE users", type: .sqlite, limit: 10))
        XCTAssertThrowsError(try DatabaseAgentToolService.readonlySQL("WITH deleted AS (DELETE FROM users RETURNING *) SELECT * FROM deleted", type: .postgresql, limit: 10))
    }

    func testReadonlySQLAddsLimitForSelectOnly() throws {
        let sql = try DatabaseAgentToolService.readonlySQL("SELECT * FROM users", type: .sqlite, limit: 25)
        XCTAssertEqual(sql, "SELECT * FROM users LIMIT 25")

        let limited = try DatabaseAgentToolService.readonlySQL("SELECT * FROM users LIMIT 5", type: .sqlite, limit: 25)
        XCTAssertEqual(limited, "SELECT * FROM users LIMIT 5")
    }

    func testListConnectionsDoesNotExposePassword() async throws {
        let config = DatabaseConfig(
            name: "Secret DB",
            type: .sqlite,
            database: ":memory:",
            username: "reader",
            password: "super-secret"
        )
        await DatabaseAgentConnectionRegistry.shared.upsert(config)

        let output = try await DatabaseListConnectionsTool().execute(arguments: [:])
        XCTAssertTrue(output.contains("Secret DB"))
        XCTAssertFalse(output.contains("super-secret"))
    }

    func testReadonlyQueryToolRunsAgainstRegisteredSQLiteConnection() async throws {
        let config = DatabaseConfig(name: "Agent Query Test", type: .sqlite, database: ":memory:")
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded()
        let connection = try await DatabaseManager.shared.connect(config: config)
        _ = try await connection.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO users (id, name) VALUES (1, 'Alice')", params: nil)
        await DatabaseAgentConnectionRegistry.shared.upsert(config)

        let output = try await DatabaseReadonlyQueryTool().execute(arguments: [
            "connection_id": ToolArgument(config.id.uuidString),
            "sql": ToolArgument("SELECT id, name FROM users"),
            "limit": ToolArgument(10),
        ])

        XCTAssertTrue(output.contains("Alice"))
        XCTAssertTrue(output.contains("rowsReturned"))
    }
}
#endif
