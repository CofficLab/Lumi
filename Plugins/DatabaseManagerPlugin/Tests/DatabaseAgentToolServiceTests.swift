import Testing
import Foundation
@testable import DatabaseManagerPlugin

/// Unit tests for the pure-logic helpers in `DatabaseAgentToolService`.
///
/// These cover the security-relevant read-only SQL guard, identifier quoting,
/// limit normalization, and value formatting — none of which require a live
/// database connection.
@Suite struct DatabaseAgentToolServicePureTests {

    // MARK: - readonlySQL

    @Test func readonlySQLAcceptsSelect() throws {
        let result = try DatabaseAgentToolService.readonlySQL(
            "SELECT * FROM users", type: .sqlite, limit: 100
        )
        #expect(result == "SELECT * FROM users LIMIT 100")
    }

    @Test func readonlySQLPreservesExistingLimit() throws {
        let result = try DatabaseAgentToolService.readonlySQL(
            "SELECT * FROM users LIMIT 5", type: .sqlite, limit: 100
        )
        #expect(result == "SELECT * FROM users LIMIT 5")
    }

    @Test func readonlySQLAcceptsPragmaForSQLite() throws {
        _ = try DatabaseAgentToolService.readonlySQL(
            "PRAGMA table_info(users)", type: .sqlite, limit: 100
        )
    }

    @Test func readonlySQLAcceptsShowForMySQL() throws {
        _ = try DatabaseAgentToolService.readonlySQL(
            "SHOW TABLES", type: .mysql, limit: 100
        )
    }

    @Test func readonlySQLRejectsEmptySQL() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.readonlySQL("   ", type: .sqlite, limit: 100)
        }
    }

    @Test func readonlySQLRejectsRedis() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.readonlySQL("SELECT 1", type: .redis, limit: 100)
        }
    }

    @Test func readonlySQLRejectsMultipleStatements() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.readonlySQL(
                "SELECT 1; DROP TABLE users", type: .sqlite, limit: 100
            )
        }
    }

    @Test func readonlySQLAllowsTrailingSemicolon() throws {
        let result = try DatabaseAgentToolService.readonlySQL(
            "SELECT 1;", type: .sqlite, limit: 100
        )
        #expect(result == "SELECT 1 LIMIT 100")
    }

    @Test func readonlySQLRejectsWriteKeywords() {
        let forbidden = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE",
                         "CREATE", "GRANT", "REVOKE", "CALL", "ATTACH"]
        for word in forbidden {
            #expect(throws: DatabaseAgentToolError.self) {
                _ = try DatabaseAgentToolService.readonlySQL(
                    "SELECT * FROM t WHERE x = \(word)()", type: .sqlite, limit: 100
                )
            }
        }
    }

    @Test func readonlySQLRejectsNonSelectFirstKeyword() {
        // `USE` is not in the allowed-first-keyword set for any DB type.
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.readonlySQL(
                "USE mydb", type: .mysql, limit: 100
            )
        }
    }

    @Test func readonlySQLRejectsDeleteStatement() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.readonlySQL(
                "DELETE FROM users", type: .sqlite, limit: 100
            )
        }
    }

    @Test func readonlySQLDoesNotAutoInjectLimitForExplain() throws {
        // EXPLAIN is allowed but not a SELECT, so no LIMIT should be appended.
        let result = try DatabaseAgentToolService.readonlySQL(
            "EXPLAIN SELECT * FROM users", type: .sqlite, limit: 100
        )
        #expect(result == "EXPLAIN SELECT * FROM users")
    }

    // MARK: - quoteIdentifier

    @Test func quoteIdentifierMySQLUsesBackticks() {
        #expect(DatabaseAgentToolService.quoteIdentifier("user", type: .mysql) == "`user`")
    }

    @Test func quoteIdentifierSQLiteUsesDoubleQuotes() {
        #expect(DatabaseAgentToolService.quoteIdentifier("user", type: .sqlite) == "\"user\"")
    }

    @Test func quoteIdentifierPostgreSQLUsesDoubleQuotes() {
        #expect(DatabaseAgentToolService.quoteIdentifier("user", type: .postgresql) == "\"user\"")
    }

    @Test func quoteIdentifierEscapesEmbeddedBacktick() {
        // ` -> `` inside MySQL quoting, preventing injection.
        #expect(DatabaseAgentToolService.quoteIdentifier("na`me", type: .mysql) == "`na``me`")
    }

    @Test func quoteIdentifierEscapesEmbeddedDoubleQuote() {
        #expect(DatabaseAgentToolService.quoteIdentifier("na\"me", type: .sqlite) == "\"na\"\"me\"")
    }

    @Test func quoteIdentifierPathJoinsComponents() {
        #expect(
            DatabaseAgentToolService.quoteIdentifierPath("schema.table", type: .postgresql)
            == "\"schema\".\"table\""
        )
    }

    // MARK: - normalizedLimit

    @Test func normalizedLimitDefaultsWhenNil() throws {
        #expect(try DatabaseAgentToolService.normalizedLimit(nil as Any?) == DatabaseAgentToolService.defaultRows)
    }

    @Test func normalizedLimitAcceptsInt() throws {
        #expect(try DatabaseAgentToolService.normalizedLimit(50 as Any?) == 50)
    }

    @Test func normalizedLimitAcceptsDouble() throws {
        #expect(try DatabaseAgentToolService.normalizedLimit(50.0 as Any?) == 50)
    }

    @Test func normalizedLimitAcceptsNumericString() throws {
        #expect(try DatabaseAgentToolService.normalizedLimit("50" as Any?) == 50)
    }

    @Test func normalizedLimitRejectsZero() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.normalizedLimit(0)
        }
    }

    @Test func normalizedLimitRejectsAboveMax() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.normalizedLimit(DatabaseAgentToolService.maxRows + 1)
        }
    }

    @Test func normalizedLimitAcceptsBoundaryValues() throws {
        #expect(try DatabaseAgentToolService.normalizedLimit(1) == 1)
        #expect(try DatabaseAgentToolService.normalizedLimit(DatabaseAgentToolService.maxRows) == DatabaseAgentToolService.maxRows)
    }

    @Test func normalizedLimitRejectsGarbageString() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.normalizedLimit("abc" as Any?)
        }
    }

    // MARK: - connectionId

    @Test func connectionIdParsesValidUUID() throws {
        let uuid = UUID()
        #expect(try DatabaseAgentToolService.connectionId(from: uuid.uuidString as Any?) == uuid)
    }

    @Test func connectionIdRejectsEmpty() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.connectionId(from: "" as Any?)
        }
    }

    @Test func connectionIdRejectsNil() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.connectionId(from: nil)
        }
    }

    @Test func connectionIdRejectsMalformed() {
        #expect(throws: DatabaseAgentToolError.self) {
            _ = try DatabaseAgentToolService.connectionId(from: "not-a-uuid" as Any?)
        }
    }

    // MARK: - valueString

    @Test func valueStringInteger() {
        #expect(DatabaseAgentToolService.valueString(.integer(42)) == "42")
    }

    @Test func valueStringNegativeInteger() {
        #expect(DatabaseAgentToolService.valueString(.integer(-7)) == "-7")
    }

    @Test func valueStringDouble() {
        #expect(DatabaseAgentToolService.valueString(.double(3.5)) == "3.5")
    }

    @Test func valueStringBool() {
        #expect(DatabaseAgentToolService.valueString(.bool(true)) == "true")
        #expect(DatabaseAgentToolService.valueString(.bool(false)) == "false")
    }

    @Test func valueStringNull() {
        #expect(DatabaseAgentToolService.valueString(.null) == "NULL")
    }

    @Test func valueStringDataShowsByteCount() {
        let data = Data([0x01, 0x02, 0x03])
        #expect(DatabaseAgentToolService.valueString(.data(data)) == "<BLOB 3 bytes>")
    }

    @Test func valueStringTruncatesLongStrings() {
        let long = String(repeating: "x", count: DatabaseAgentToolService.maxCellLength + 10)
        let result = DatabaseAgentToolService.valueString(.string(long))
        #expect(result.hasSuffix("...(truncated)"))
        #expect(result.count == DatabaseAgentToolService.maxCellLength + "...(truncated)".count)
    }

    @Test func valueStringDoesNotTruncateAtBoundary() {
        let exact = String(repeating: "x", count: DatabaseAgentToolService.maxCellLength)
        #expect(DatabaseAgentToolService.valueString(.string(exact)) == exact)
    }

    // MARK: - rowsAsDictionaries

    @Test func rowsAsDictionariesMapsValues() {
        let result = QueryResult(
            columns: ["id", "name"],
            rows: [[.integer(1), .string("alice")], [.integer(2), .null]],
            rowsAffected: 0
        )
        let payload = DatabaseAgentToolService.rowsAsDictionaries(result, limit: 100)
        #expect(payload.columns == ["id", "name"])
        #expect(payload.rows == [["1", "alice"], ["2", "NULL"]])
        #expect(payload.rowsReturned == 2)
        #expect(payload.truncated == false)
    }

    @Test func rowsAsDictionariesTruncatesAndFlags() {
        let rows: [[DatabaseValue]] = (0...5).map { [.integer($0)] }
        let result = QueryResult(columns: ["id"], rows: rows, rowsAffected: 0)
        let payload = DatabaseAgentToolService.rowsAsDictionaries(result, limit: 3)
        #expect(payload.rowsReturned == 3)
        #expect(payload.truncated == true)
    }
}
