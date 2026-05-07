import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLiteDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .sqlite }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        guard !config.database.isEmpty else {
            throw DatabaseError.invalidConfiguration("Database path is required for SQLite")
        }
        return try SQLiteConnection(path: config.database)
    }
}

public actor SQLiteConnection: DatabaseConnection {
    private var db: OpaquePointer?

    public init(path: String) throws {
        var dbPointer: OpaquePointer?
        if sqlite3_open(path, &dbPointer) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(dbPointer))
            sqlite3_close(dbPointer)
            throw DatabaseError.connectionFailed(errorMsg)
        }
        self.db = dbPointer
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard let db else { throw DatabaseError.connectionFailed("Connection closed") }

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(errorMsg)
        }
        defer { sqlite3_finalize(statement) }

        if let params {
            for (index, param) in params.enumerated() {
                bind(statement: statement, index: index + 1, value: param)
            }
        }

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(errorMsg)
        }

        return Int(sqlite3_changes(db))
    }

    public func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        guard let db else { throw DatabaseError.connectionFailed("Connection closed") }

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(errorMsg)
        }
        defer { sqlite3_finalize(statement) }

        if let params {
            for (index, param) in params.enumerated() {
                bind(statement: statement, index: index + 1, value: param)
            }
        }

        var columns: [String] = []
        var rows: [[DatabaseValue]] = []
        let columnCount = sqlite3_column_count(statement)

        for i in 0..<columnCount {
            if let name = sqlite3_column_name(statement, i) {
                columns.append(String(cString: name))
            } else {
                columns.append("Column \(i)")
            }
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [DatabaseValue] = []
            for i in 0..<columnCount {
                switch sqlite3_column_type(statement, i) {
                case SQLITE_INTEGER:
                    row.append(.integer(Int(sqlite3_column_int64(statement, i))))
                case SQLITE_FLOAT:
                    row.append(.double(Double(sqlite3_column_double(statement, i))))
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, i) {
                        row.append(.string(String(cString: text)))
                    } else {
                        row.append(.null)
                    }
                case SQLITE_BLOB:
                    if let blob = sqlite3_column_blob(statement, i) {
                        let bytes = sqlite3_column_bytes(statement, i)
                        row.append(.data(Data(bytes: blob, count: Int(bytes))))
                    } else {
                        row.append(.null)
                    }
                case SQLITE_NULL:
                    row.append(.null)
                default:
                    row.append(.null)
                }
            }
            rows.append(row)
        }

        return QueryResult(columns: columns, rows: rows, rowsAffected: 0)
    }

    public func beginTransaction() async throws -> any DatabaseTransaction {
        _ = try await execute("BEGIN TRANSACTION", params: nil)
        return SQLiteTransaction(connection: self)
    }

    public func close() async {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    public func isAlive() async -> Bool {
        db != nil
    }

    private func bind(statement: OpaquePointer?, index: Int, value: DatabaseValue) {
        switch value {
        case .integer(let intValue):
            sqlite3_bind_int64(statement, Int32(index), Int64(intValue))
        case .double(let doubleValue):
            sqlite3_bind_double(statement, Int32(index), doubleValue)
        case .string(let stringValue):
            sqlite3_bind_text(statement, Int32(index), stringValue, -1, sqliteTransient)
        case .bool(let boolValue):
            sqlite3_bind_int(statement, Int32(index), boolValue ? 1 : 0)
        case .data(let dataValue):
            _ = dataValue.withUnsafeBytes { ptr in
                sqlite3_bind_blob(statement, Int32(index), ptr.baseAddress, Int32(dataValue.count), sqliteTransient)
            }
        case .null:
            sqlite3_bind_null(statement, Int32(index))
        }
    }
}

public final actor SQLiteTransaction: DatabaseTransaction {
    private let connection: SQLiteConnection
    private var completed = false

    init(connection: SQLiteConnection) {
        self.connection = connection
    }

    public func commit() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("COMMIT", params: nil)
        completed = true
    }

    public func rollback() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("ROLLBACK", params: nil)
        completed = true
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        return try await connection.execute(sql, params: params)
    }
}
