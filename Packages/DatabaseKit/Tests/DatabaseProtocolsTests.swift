import Foundation
import Testing
@testable import DatabaseKit

struct DatabaseProtocolsTests {
    @Test
    func databaseTypeEnumCasesAreCorrect() {
        #expect(DatabaseType.sqlite.rawValue == "SQLite")
        #expect(DatabaseType.postgresql.rawValue == "PostgreSQL")
        #expect(DatabaseType.mysql.rawValue == "MySQL")
        #expect(DatabaseType.redis.rawValue == "Redis")
        #expect(DatabaseType.allCases.count == 4)
    }

    @Test
    func databaseTypeIsCodable() throws {
        let original = DatabaseType.mysql
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DatabaseType.self, from: encoded)
        #expect(decoded == original)
    }

    @Test
    func databaseConfigDefaultsToRandomUUID() {
        let config1 = DatabaseConfig(name: "Test1", type: .sqlite, database: "test1.sqlite")
        let config2 = DatabaseConfig(name: "Test2", type: .sqlite, database: "test2.sqlite")

        #expect(config1.id != config2.id)
    }

    @Test
    func databaseConfigCanHaveCustomUUID() {
        let customID = UUID()
        let config = DatabaseConfig(id: customID, name: "Custom", type: .sqlite, database: "custom.sqlite")

        #expect(config.id == customID)
    }

    @Test
    func databaseConfigStoresAllParameters() {
        let config = DatabaseConfig(
            name: "Full Config",
            type: .postgresql,
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: "user",
            password: "pass",
            options: ["ssl": "true"]
        )

        #expect(config.name == "Full Config")
        #expect(config.type == .postgresql)
        #expect(config.host == "localhost")
        #expect(config.port == 5432)
        #expect(config.database == "mydb")
        #expect(config.username == "user")
        #expect(config.password == "pass")
        #expect(config.options?["ssl"] == "true")
    }

    @Test
    func databaseConfigIsCodable() throws {
        let config = DatabaseConfig(
            name: "Codable Test",
            type: .mysql,
            host: "192.168.1.1",
            port: 3306,
            database: "testdb",
            username: "testuser",
            password: "testpass",
            options: ["timeout": "30"]
        )

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DatabaseConfig.self, from: encoded)

        #expect(decoded.id == config.id)
        #expect(decoded.name == config.name)
        #expect(decoded.type == config.type)
        #expect(decoded.host == config.host)
        #expect(decoded.port == config.port)
        #expect(decoded.database == config.database)
        #expect(decoded.username == config.username)
        #expect(decoded.password == config.password)
        #expect(decoded.options == config.options)
    }

    @Test
    func databaseConfigIsHashable() {
        let config1 = DatabaseConfig(name: "Hash Test", type: .sqlite, database: "hash.sqlite")
        let config2 = DatabaseConfig(name: "Hash Test", type: .sqlite, database: "hash.sqlite")

        // Different UUIDs, so should not be equal
        #expect(config1 != config2)
        #expect(config1.id != config2.id)
    }

    @Test
    func databaseErrorConnectionFailed() {
        let error = DatabaseError.connectionFailed("timeout")
        #expect(error.errorDescription == "Connection failed: timeout")
    }

    @Test
    func databaseErrorQueryFailed() {
        let error = DatabaseError.queryFailed("syntax error")
        #expect(error.errorDescription == "Query execution failed: syntax error")
    }

    @Test
    func databaseErrorTransactionFailed() {
        let error = DatabaseError.transactionFailed("deadlock")
        #expect(error.errorDescription == "Transaction failed: deadlock")
    }

    @Test
    func databaseErrorDriverNotFound() {
        let error = DatabaseError.driverNotFound(.redis)
        #expect(error.errorDescription == "Driver not found for type: Redis")
    }

    @Test
    func databaseErrorInvalidConfiguration() {
        let error = DatabaseError.invalidConfiguration("missing host")
        #expect(error.errorDescription == "Invalid configuration: missing host")
    }

    @Test
    func databaseErrorNotImplemented() {
        let error = DatabaseError.notImplemented
        #expect(error.errorDescription == "Feature not implemented yet")
    }

    @Test
    func databaseValueIntegerDescription() {
        let value = DatabaseValue.integer(42)
        #expect(value.description == "42")
    }

    @Test
    func databaseValueDoubleDescription() {
        let value = DatabaseValue.double(3.14)
        #expect(value.description == "3.14")
    }

    @Test
    func databaseValueStringDescription() {
        let value = DatabaseValue.string("hello")
        #expect(value.description == "hello")
    }

    @Test
    func databaseValueDataDescription() {
        let data = Data([1, 2, 3, 4, 5])
        let value = DatabaseValue.data(data)
        #expect(value.description == "5 bytes")
    }

    @Test
    func databaseValueBoolTrueDescription() {
        let value = DatabaseValue.bool(true)
        #expect(value.description == "true")
    }

    @Test
    func databaseValueBoolFalseDescription() {
        let value = DatabaseValue.bool(false)
        #expect(value.description == "false")
    }

    @Test
    func databaseValueNullDescription() {
        let value = DatabaseValue.null
        #expect(value.description == "NULL")
    }

    @Test
    func databaseValueEquality() {
        #expect(DatabaseValue.integer(10) == DatabaseValue.integer(10))
        #expect(DatabaseValue.integer(10) != DatabaseValue.integer(20))
        #expect(DatabaseValue.string("a") == DatabaseValue.string("a"))
        #expect(DatabaseValue.bool(true) == DatabaseValue.bool(true))
        #expect(DatabaseValue.null == DatabaseValue.null)
        #expect(DatabaseValue.integer(10) != DatabaseValue.string("10"))
    }

    @Test
    func queryResultInitialization() {
        let result = QueryResult(
            columns: ["id", "name"],
            rows: [[.integer(1), .string("Alice")], [.integer(2), .string("Bob")]],
            rowsAffected: 2
        )

        #expect(result.columns == ["id", "name"])
        #expect(result.rows.count == 2)
        #expect(result.rowsAffected == 2)
    }

    @Test
    func queryResultEquality() {
        let result1 = QueryResult(
            columns: ["a"],
            rows: [[.integer(1)]],
            rowsAffected: 1
        )
        let result2 = QueryResult(
            columns: ["a"],
            rows: [[.integer(1)]],
            rowsAffected: 1
        )
        let result3 = QueryResult(
            columns: ["b"],
            rows: [[.integer(2)]],
            rowsAffected: 1
        )

        #expect(result1 == result2)
        #expect(result1 != result3)
    }

    @Test
    func queryResultEmptyRows() {
        let result = QueryResult(columns: ["col1"], rows: [], rowsAffected: 0)

        #expect(result.rows.isEmpty)
        #expect(result.rowsAffected == 0)
    }
}