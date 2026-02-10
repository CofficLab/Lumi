import Foundation
import SQLite3

actor SQLiteConnection: DatabaseConnection {
    private var db: OpaquePointer?
    private let path: String
    
    init(path: String) throws {
        self.path = path
        // Open connection
        var dbPointer: OpaquePointer?
        if sqlite3_open(path, &dbPointer) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(dbPointer))
            sqlite3_close(dbPointer)
            throw DatabaseError.connectionFailed(errorMsg)
        }
        self.db = dbPointer
    }
    
    deinit {
        // Actors don't guarantee main thread deinit, but sqlite3_close is thread-safe
        // However, we can't access 'db' directly in deinit of an actor if it's isolated state?
        // Actually, actor properties are protected. But deinit is special.
        // We should close explicitly.
        // For C-pointers, we might need a wrapper if we want safe deinit.
        // But let's rely on explicit close() for now, or just leak if not closed?
        // No, we can access non-isolated properties. 'db' is isolated.
        // Let's remove deinit logic and rely on close().
        // Or better: make 'db' a non-isolated UnsafeMutablePointer wrapper class that handles deinit?
    }
    
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        // No need for continuation if we are in actor?
        // Actually sqlite3 functions are blocking C calls.
        // We should probably run them on a detached task or just block the actor (since it's a serial executor).
        // Blocking the actor is fine for simple queries.
        
        guard let db = db else { throw DatabaseError.connectionFailed("Connection closed") }
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(errorMsg)
        }
        
        // Bind params
        if let params = params {
            for (index, param) in params.enumerated() {
                bind(statement: statement, index: index + 1, value: param)
            }
        }
        
        if sqlite3_step(statement) != SQLITE_DONE {
             let errorMsg = String(cString: sqlite3_errmsg(db))
             sqlite3_finalize(statement)
             throw DatabaseError.queryFailed(errorMsg)
        }
        
        let changes = Int(sqlite3_changes(db))
        sqlite3_finalize(statement)
        return changes
    }
    
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        guard let db = db else { throw DatabaseError.connectionFailed("Connection closed") }
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed(errorMsg)
        }
        
        // Bind params
        if let params = params {
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
                let type = sqlite3_column_type(statement, i)
                switch type {
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
        
        sqlite3_finalize(statement)
        return QueryResult(columns: columns, rows: rows, rowsAffected: 0)
    }
    
    func beginTransaction() async throws -> DatabaseTransaction {
        // Simple transaction implementation
        _ = try await execute("BEGIN TRANSACTION", params: nil)
        return SQLiteTransaction(connection: self)
    }
    
    func close() async {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    func isAlive() async -> Bool {
        return db != nil
    }
    
    private func bind(statement: OpaquePointer?, index: Int, value: DatabaseValue) {
        switch value {
        case .integer(let intValue):
            sqlite3_bind_int64(statement, Int32(index), Int64(intValue))
        case .double(let doubleValue):
            sqlite3_bind_double(statement, Int32(index), doubleValue)
        case .string(let stringValue):
            sqlite3_bind_text(statement, Int32(index), (stringValue as NSString).utf8String, -1, nil)
        case .bool(let boolValue):
            sqlite3_bind_int(statement, Int32(index), boolValue ? 1 : 0)
        case .data(let dataValue):
            dataValue.withUnsafeBytes { ptr in
                sqlite3_bind_blob(statement, Int32(index), ptr.baseAddress, Int32(dataValue.count), nil)
            }
        case .null:
            sqlite3_bind_null(statement, Int32(index))
        }
    }
}

final actor SQLiteTransaction: DatabaseTransaction {
    let connection: SQLiteConnection
    private var completed = false
    
    init(connection: SQLiteConnection) {
        self.connection = connection
    }
    
    func commit() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("COMMIT", params: nil)
        completed = true
    }
    
    func rollback() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("ROLLBACK", params: nil)
        completed = true
    }
    
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        return try await connection.execute(sql, params: params)
    }
}
