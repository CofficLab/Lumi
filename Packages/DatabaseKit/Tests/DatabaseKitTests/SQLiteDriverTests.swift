import Foundation
import Testing
@testable import DatabaseKit

struct SQLiteDriverTests {
    @Test
    func sqliteDriverTypeIsSQLite() {
        let driver = SQLiteDriver()
        #expect(driver.type == .sqlite)
    }

    @Test
    func sqliteDriverRejectsEmptyDatabasePath() async throws {
        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Empty Path", type: .sqlite, database: "")

        do {
            _ = try await driver.connect(config: config)
            Issue.record("Should have thrown error")
        } catch DatabaseError.invalidConfiguration(_) {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func sqliteDriverConnectsToValidPath() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "SQLite Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        #expect(connection is SQLiteConnection)
        #expect(await connection.isAlive())

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionCreateTable() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Table Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        let changes = try await connection.execute(
            "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT, value REAL)",
            params: nil
        )

        #expect(changes == 0)

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionInsertData() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Insert Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        // Create table
        _ = try await connection.execute(
            "CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT, count INTEGER)",
            params: nil
        )

        // Insert data with parameters
        let changes = try await connection.execute(
            "INSERT INTO items (name, count) VALUES (?, ?)",
            params: [.string("test-item"), .integer(42)]
        )

        #expect(changes == 1)

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionQueryData() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Query Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        // Setup
        _ = try await connection.execute("CREATE TABLE items (name TEXT, count INTEGER)", params: nil)
        _ = try await connection.execute("INSERT INTO items VALUES ('item1', 10)", params: nil)
        _ = try await connection.execute("INSERT INTO items VALUES ('item2', 20)", params: nil)

        // Query
        let result = try await connection.query("SELECT name, count FROM items", params: nil)

        #expect(result.columns == ["name", "count"])
        #expect(result.rows.count == 2)
        #expect(result.rows[0] == [.string("item1"), .integer(10)])
        #expect(result.rows[1] == [.string("item2"), .integer(20)])

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionQueryWithParameters() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Param Query Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        // Setup
        _ = try await connection.execute("CREATE TABLE items (name TEXT, count INTEGER)", params: nil)
        _ = try await connection.execute("INSERT INTO items VALUES ('apple', 5)", params: nil)
        _ = try await connection.execute("INSERT INTO items VALUES ('banana', 10)", params: nil)

        // Query with parameter
        let result = try await connection.query(
            "SELECT name, count FROM items WHERE name = ?",
            params: [.string("apple")]
        )

        #expect(result.rows.count == 1)
        #expect(result.rows[0] == [.string("apple"), .integer(5)])

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionQueryEmptyResult() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Empty Result Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)

        let result = try await connection.query("SELECT name FROM items WHERE name = 'nonexistent'", params: nil)

        #expect(result.rows.isEmpty)

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionBindAllParameterTypes() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Bind Types Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        // Create table with all types
        _ = try await connection.execute(
            "CREATE TABLE all_types (int INTEGER, real REAL, text TEXT, blob BLOB, bool INTEGER, null_val INTEGER)",
            params: nil
        )

        // Insert with all parameter types
        _ = try await connection.execute(
            "INSERT INTO all_types VALUES (?, ?, ?, ?, ?, ?)",
            params: [
                .integer(100),
                .double(3.14),
                .string("hello"),
                .data(Data([1, 2, 3])),
                .bool(true),
                .null
            ]
        )

        // Query and verify
        let result = try await connection.query("SELECT * FROM all_types", params: nil)

        #expect(result.rows.count == 1)
        #expect(result.rows[0][0] == .integer(100))
        #expect(result.rows[0][1] == .double(3.14))
        #expect(result.rows[0][2] == .string("hello"))
        #expect(result.rows[0][3] == .data(Data([1, 2, 3])))
        #expect(result.rows[0][4] == .integer(1))  // bool stored as integer
        #expect(result.rows[0][5] == .null)

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionTransactionCommit() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Transaction Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)

        let transaction = try await connection.beginTransaction()

        _ = try await transaction.execute("INSERT INTO items VALUES ('item1')", params: nil)
        _ = try await transaction.execute("INSERT INTO items VALUES ('item2')", params: nil)

        try await transaction.commit()

        let result = try await connection.query("SELECT name FROM items", params: nil)
        #expect(result.rows.count == 2)

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionTransactionRollback() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Rollback Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO items VALUES ('initial')", params: nil)

        let transaction = try await connection.beginTransaction()

        _ = try await transaction.execute("INSERT INTO items VALUES ('item1')", params: nil)
        _ = try await transaction.execute("INSERT INTO items VALUES ('item2')", params: nil)

        try await transaction.rollback()

        let result = try await connection.query("SELECT name FROM items", params: nil)
        #expect(result.rows.count == 1)  // Only the initial item

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteTransactionThrowsOnDoubleCommit() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Double Commit Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)

        let transaction = try await connection.beginTransaction()
        try await transaction.commit()

        do {
            try await transaction.commit()
            Issue.record("Should have thrown error")
        } catch DatabaseError.transactionFailed(_) {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteTransactionThrowsOnDoubleRollback() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Double Rollback Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)

        let transaction = try await connection.beginTransaction()
        try await transaction.rollback()

        do {
            try await transaction.rollback()
            Issue.record("Should have thrown error")
        } catch DatabaseError.transactionFailed(_) {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteTransactionThrowsOnExecuteAfterCommit() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Execute After Commit Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)

        let transaction = try await connection.beginTransaction()
        try await transaction.commit()

        do {
            _ = try await transaction.execute("INSERT INTO items VALUES ('test')", params: nil)
            Issue.record("Should have thrown error")
        } catch DatabaseError.transactionFailed(_) {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionCloseSetsIsAliveFalse() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "IsAlive Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        #expect(await connection.isAlive())

        await connection.close()
        #expect(await connection.isAlive() == false)

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionThrowsAfterClose() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Execute After Close Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        await connection.close()

        do {
            _ = try await connection.execute("SELECT 1", params: nil)
            Issue.record("Should have thrown error")
        } catch DatabaseError.connectionFailed(_) {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionThrowsOnInvalidSQL() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Invalid SQL Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        do {
            _ = try await connection.execute("INVALID SQL STATEMENT", params: nil)
            Issue.record("Should have thrown error")
        } catch DatabaseError.queryFailed(_) {
            // Expected error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test
    func sqliteConnectionHandlesUnicode() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let driver = SQLiteDriver()
        let config = DatabaseConfig(name: "Unicode Test", type: .sqlite, database: fileURL.path)
        let connection = try await driver.connect(config: config)

        _ = try await connection.execute("CREATE TABLE items (name TEXT)", params: nil)
        _ = try await connection.execute("INSERT INTO items VALUES (?)", params: [.string("你好世界 🎉")])

        let result = try await connection.query("SELECT name FROM items", params: nil)

        #expect(result.rows.count == 1)
        #expect(result.rows[0][0] == .string("你好世界 🎉"))

        await connection.close()
        try? FileManager.default.removeItem(at: fileURL)
    }
}