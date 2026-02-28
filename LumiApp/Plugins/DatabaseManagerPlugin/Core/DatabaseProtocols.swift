import Foundation

/// Supported Database Types
enum DatabaseType: String, CaseIterable, Codable {
    case sqlite = "SQLite"
    case postgresql = "PostgreSQL"
    case mysql = "MySQL"
    case redis = "Redis"
}

/// Database Configuration
struct DatabaseConfig: Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: DatabaseType
    var host: String?
    var port: Int?
    var database: String // File path for SQLite, DB name for others
    var username: String?
    var password: String?
    var options: [String: String]?
}

/// Core Database Error
enum DatabaseError: Error, LocalizedError {
    case connectionFailed(String)
    case queryFailed(String)
    case transactionFailed(String)
    case driverNotFound(DatabaseType)
    case invalidConfiguration(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .queryFailed(let msg): return "Query execution failed: \(msg)"
        case .transactionFailed(let msg): return "Transaction failed: \(msg)"
        case .driverNotFound(let type): return "Driver not found for type: \(type.rawValue)"
        case .invalidConfiguration(let msg): return "Invalid configuration: \(msg)"
        case .notImplemented: return "Feature not implemented yet"
        }
    }
}

/// Database Value Type (Sendable)
public enum DatabaseValue: Sendable, Equatable, CustomStringConvertible {
    case integer(Int)
    case double(Double)
    case string(String)
    case data(Data)
    case bool(Bool)
    case null
    
    public var description: String {
        switch self {
        case .integer(let v): return String(v)
        case .double(let v): return String(v)
        case .string(let v): return v
        case .data(let v): return "\(v.count) bytes"
        case .bool(let v): return String(v)
        case .null: return "NULL"
        }
    }
}

/// Query Result Structure
public struct QueryResult: Sendable {
    public var columns: [String]
    public var rows: [[DatabaseValue]]
    public var rowsAffected: Int
    
    public init(columns: [String], rows: [[DatabaseValue]], rowsAffected: Int) {
        self.columns = columns
        self.rows = rows
        self.rowsAffected = rowsAffected
    }
}

/// Protocol for Database Drivers (Factory)
protocol DatabaseDriver: Sendable {
    var type: DatabaseType { get }
    func connect(config: DatabaseConfig) async throws -> DatabaseConnection
}

/// Protocol for an active Database Connection
protocol DatabaseConnection: Sendable {
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int // Returns rows affected
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult
    func beginTransaction() async throws -> DatabaseTransaction
    func close() async
    func isAlive() async -> Bool
}

/// Protocol for Database Transactions
protocol DatabaseTransaction: Sendable {
    func commit() async throws
    func rollback() async throws
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int
}
