import Foundation

public enum DatabaseType: String, CaseIterable, Codable, Sendable {
    case sqlite = "SQLite"
    case postgresql = "PostgreSQL"
    case mysql = "MySQL"
    case redis = "Redis"
}

public struct DatabaseConfig: Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var type: DatabaseType
    public var host: String?
    public var port: Int?
    public var database: String
    public var username: String?
    public var password: String?
    public var options: [String: String]?

    public init(
        id: UUID = UUID(),
        name: String,
        type: DatabaseType,
        host: String? = nil,
        port: Int? = nil,
        database: String,
        username: String? = nil,
        password: String? = nil,
        options: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.password = password
        self.options = options
    }
}

extension DatabaseConfig {
    func validatedNetworkPort(default defaultPort: Int? = nil, serviceName: String) throws -> Int {
        guard let port = port ?? defaultPort, (1...65535).contains(port) else {
            throw DatabaseError.invalidConfiguration("\(serviceName) 需要 1 到 65535 之间的端口")
        }
        return port
    }
}

public enum DatabaseError: Error, LocalizedError, Sendable {
    case connectionFailed(String)
    case queryFailed(String)
    case transactionFailed(String)
    case driverNotFound(DatabaseType)
    case invalidConfiguration(String)
    case notImplemented

    public var errorDescription: String? {
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

public struct QueryResult: Sendable, Equatable {
    public var columns: [String]
    public var rows: [[DatabaseValue]]
    public var rowsAffected: Int

    public init(columns: [String], rows: [[DatabaseValue]], rowsAffected: Int) {
        self.columns = columns
        self.rows = rows
        self.rowsAffected = rowsAffected
    }
}

public protocol DatabaseDriver: Sendable {
    var type: DatabaseType { get }
    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection
}

public protocol DatabaseConnection: AnyObject, Sendable {
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult
    func beginTransaction() async throws -> any DatabaseTransaction
    func close() async
    func isAlive() async -> Bool
}

public protocol DatabaseTransaction: Sendable {
    func commit() async throws
    func rollback() async throws
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int
}
