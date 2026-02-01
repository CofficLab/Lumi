import Foundation
import SQLite3

class SQLiteConnection: DatabaseConnection {
    private var db: OpaquePointer?
    private let path: String
    
    init(path: String) throws {
        self.path = path
        // Open connection
        if sqlite3_open(path, &db) != SQLITE_OK {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw DatabaseError.connectionFailed(errorMsg)
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    func execute(_ sql: String, params: [Any]?) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                continuation.resume(throwing: DatabaseError.queryFailed(errorMsg))
                return
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
                 continuation.resume(throwing: DatabaseError.queryFailed(errorMsg))
                 return
            }
            
            let changes = Int(sqlite3_changes(db))
            sqlite3_finalize(statement)
            continuation.resume(returning: changes)
        }
    }
    
    func query(_ sql: String, params: [Any]?) async throws -> QueryResult {
        return try await withCheckedThrowingContinuation { continuation in
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                continuation.resume(throwing: DatabaseError.queryFailed(errorMsg))
                return
            }
            
            // Bind params
            if let params = params {
                for (index, param) in params.enumerated() {
                    bind(statement: statement, index: index + 1, value: param)
                }
            }
            
            var columns: [String] = []
            var rows: [[Any?]] = []
            
            let columnCount = sqlite3_column_count(statement)
            for i in 0..<columnCount {
                if let name = sqlite3_column_name(statement, i) {
                    columns.append(String(cString: name))
                } else {
                    columns.append("Column \(i)")
                }
            }
            
            while sqlite3_step(statement) == SQLITE_ROW {
                var row: [Any?] = []
                for i in 0..<columnCount {
                    let type = sqlite3_column_type(statement, i)
                    switch type {
                    case SQLITE_INTEGER:
                        row.append(Int(sqlite3_column_int64(statement, i)))
                    case SQLITE_FLOAT:
                        row.append(sqlite3_column_double(statement, i))
                    case SQLITE_TEXT:
                        if let text = sqlite3_column_text(statement, i) {
                            row.append(String(cString: text))
                        } else {
                            row.append(nil)
                        }
                    case SQLITE_BLOB:
                        // Handle blob as Data if needed, or simplified string
                         if let blob = sqlite3_column_blob(statement, i) {
                             let size = sqlite3_column_bytes(statement, i)
                             let data = Data(bytes: blob, count: Int(size))
                             row.append(data) // Return Data object
                         } else {
                             row.append(nil)
                         }
                    case SQLITE_NULL:
                        row.append(nil)
                    default:
                        row.append(nil)
                    }
                }
                rows.append(row)
            }
            
            sqlite3_finalize(statement)
            continuation.resume(returning: QueryResult(columns: columns, rows: rows, rowsAffected: 0))
        }
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
    
    private func bind(statement: OpaquePointer?, index: Int, value: Any) {
        if let intValue = value as? Int {
            sqlite3_bind_int64(statement, Int32(index), Int64(intValue))
        } else if let doubleValue = value as? Double {
            sqlite3_bind_double(statement, Int32(index), doubleValue)
        } else if let stringValue = value as? String {
            sqlite3_bind_text(statement, Int32(index), (stringValue as NSString).utf8String, -1, nil)
        } else if value is NSNull {
            sqlite3_bind_null(statement, Int32(index))
        } else if let boolValue = value as? Bool {
            sqlite3_bind_int(statement, Int32(index), boolValue ? 1 : 0)
        } else {
            // Default to string representation
            let stringValue = "\(value)"
            sqlite3_bind_text(statement, Int32(index), (stringValue as NSString).utf8String, -1, nil)
        }
    }
}

class SQLiteTransaction: DatabaseTransaction {
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
    
    func execute(_ sql: String, params: [Any]?) async throws -> Int {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        return try await connection.execute(sql, params: params)
    }
}
