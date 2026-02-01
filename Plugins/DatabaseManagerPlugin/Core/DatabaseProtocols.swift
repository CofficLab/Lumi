import Foundation

/// Supported Database Types
enum DatabaseType: String, CaseIterable, Codable {
    case sqlite = "SQLite"
    case postgresql = "PostgreSQL"
    case mysql = "MySQL"
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

/// Query Result Structure
struct QueryResult {
    var columns: [String]
    var rows: [[Any?]]
    var rowsAffected: Int
}

/// Protocol for Database Drivers (Factory)
protocol DatabaseDriver {
    var type: DatabaseType { get }
    func connect(config: DatabaseConfig) async throws -> DatabaseConnection
}

/// Protocol for an active Database Connection
protocol DatabaseConnection {
    func execute(_ sql: String, params: [Any]?) async throws -> Int // Returns rows affected
    func query(_ sql: String, params: [Any]?) async throws -> QueryResult
    func beginTransaction() async throws -> DatabaseTransaction
    func close() async
    func isAlive() async -> Bool
}

/// Protocol for Database Transactions
protocol DatabaseTransaction {
    func commit() async throws
    func rollback() async throws
    func execute(_ sql: String, params: [Any]?) async throws -> Int
}
