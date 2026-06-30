import Foundation

public struct DatabaseConnectionSummary: Encodable {
    public let id: String
    public let name: String
    public let type: String
    public let host: String?
    public let port: Int?
    public let database: String
}

public struct DatabaseQueryPayload: Encodable {
    public let columns: [String]
    public let rows: [[String]]
    public let rowsReturned: Int
    public let rowsAffected: Int
    public let truncated: Bool
}

public enum DatabaseAgentToolError: LocalizedError {
    case missingArgument(String)
    case invalidConnectionId(String)
    case connectionNotFound(String)
    case unsafeSQL(String)
    case invalidLimit
    case unsupportedDatabaseType(String)

    public var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidConnectionId(let value):
            return "Invalid connection_id: \(value)"
        case .connectionNotFound(let id):
            return "Database connection is not available to Agent tools: \(id)"
        case .unsafeSQL(let reason):
            return "SQL rejected by read-only policy: \(reason)"
        case .invalidLimit:
            return "limit must be between 1 and \(DatabaseAgentToolService.maxRows)"
        case .unsupportedDatabaseType(let type):
            return "Unsupported database type for this tool: \(type)"
        }
    }
}

public actor DatabaseAgentToolService {
    public static let shared = DatabaseAgentToolService()
    public static let maxRows = 1_000
    public static let defaultRows = 100
    public static let maxCellLength = 2_000

    private let manager = DatabaseManagerCore.shared
    private let registry = DatabaseAgentConnectionRegistry.shared

    private init() {}

    public func listConnections() async throws -> String {
        let configs = await registry.allConfigs()
        let summaries = configs.map { config in
            DatabaseConnectionSummary(
                id: config.id.uuidString,
                name: config.name,
                type: config.type.rawValue,
                host: config.host,
                port: config.port,
                database: config.database
            )
        }
        return try Self.encodeJSON(summaries)
    }

    public func describeSchema(connectionId: UUID, limit: Int) async throws -> String {
        let limit = try Self.normalizedLimit(limit)
        let config = try await config(for: connectionId)
        let connection = try await connection(for: config)

        switch config.type {
        case .sqlite:
            let tables = try await connection.query(
                "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') ORDER BY name LIMIT \(limit)",
                params: nil
            )
            var payload: [[String: Any]] = []
            for row in tables.rows {
                guard let name = row.first?.description, !name.isEmpty else { continue }
                let columns = try await connection.query("PRAGMA table_info(\(Self.quoteIdentifier(name, type: .sqlite)))", params: nil)
                payload.append([
                    "name": name,
                    "kind": row.dropFirst().first?.description ?? "table",
                    "columns": Self.rowsAsDictionaries(columns, limit: limit).rows,
                ])
            }
            return try Self.encodeJSONObject(["tables": payload])
        case .mysql:
            let result = try await connection.query(
                """
                SELECT table_name, column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_schema = DATABASE()
                ORDER BY table_name, ordinal_position
                LIMIT \(limit)
                """,
                params: nil
            )
            return try Self.encodeJSON(Self.rowsAsDictionaries(result, limit: limit))
        case .postgresql:
            let result = try await connection.query(
                """
                SELECT table_name, column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_schema = 'public'
                ORDER BY table_name, ordinal_position
                LIMIT \(limit)
                """,
                params: nil
            )
            return try Self.encodeJSON(Self.rowsAsDictionaries(result, limit: limit))
        case .redis:
            let result = try await connection.query("SCAN 0 MATCH * COUNT \(min(limit, 100))", params: nil)
            return try Self.encodeJSON(Self.rowsAsDictionaries(result, limit: limit))
        }
    }

    public func queryReadonly(connectionId: UUID, sql: String, limit: Int) async throws -> String {
        let limit = try Self.normalizedLimit(limit)
        let config = try await config(for: connectionId)
        let checkedSQL = try Self.readonlySQL(sql, type: config.type, limit: limit)
        let connection = try await connection(for: config)
        let result = try await connection.query(checkedSQL, params: nil)
        return try Self.encodeJSON(Self.rowsAsDictionaries(result, limit: limit))
    }

    public func sampleTable(connectionId: UUID, table: String, limit: Int) async throws -> String {
        let limit = try Self.normalizedLimit(limit)
        let config = try await config(for: connectionId)
        guard config.type != .redis else {
            throw DatabaseAgentToolError.unsupportedDatabaseType(config.type.rawValue)
        }
        let quoted = Self.quoteIdentifierPath(table, type: config.type)
        return try await queryReadonly(connectionId: connectionId, sql: "SELECT * FROM \(quoted) LIMIT \(limit)", limit: limit)
    }

    private func config(for id: UUID) async throws -> DatabaseConfig {
        guard let config = await registry.config(id: id) else {
            throw DatabaseAgentToolError.connectionNotFound(id.uuidString)
        }
        return config
    }

    private func connection(for config: DatabaseConfig) async throws -> any DatabaseConnection {
        await DatabaseDriverBootstrap.registerBuiltinsIfNeeded(on: manager)
        if let connection = await manager.getConnection(for: config.id), await connection.isAlive() {
            return connection
        }
        return try await manager.connect(config: config)
    }

    public static func connectionId(from value: Any?) throws -> UUID {
        guard let raw = value as? String, !raw.isEmpty else {
            throw DatabaseAgentToolError.missingArgument("connection_id")
        }
        guard let id = UUID(uuidString: raw) else {
            throw DatabaseAgentToolError.invalidConnectionId(raw)
        }
        return id
    }

    public static func normalizedLimit(_ value: Any?) throws -> Int {
        if value == nil { return defaultRows }
        if let int = value as? Int {
            return try normalizedLimit(int)
        }
        if let double = value as? Double {
            return try normalizedLimit(Int(double))
        }
        if let string = value as? String, let int = Int(string) {
            return try normalizedLimit(int)
        }
        throw DatabaseAgentToolError.invalidLimit
    }

    public static func normalizedLimit(_ limit: Int) throws -> Int {
        guard limit >= 1, limit <= maxRows else {
            throw DatabaseAgentToolError.invalidLimit
        }
        return limit
    }

    public static func readonlySQL(_ sql: String, type: DatabaseType, limit: Int) throws -> String {
        guard type != .redis else {
            throw DatabaseAgentToolError.unsupportedDatabaseType(type.rawValue)
        }

        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DatabaseAgentToolError.missingArgument("sql")
        }

        let withoutTrailingSemicolon = trimmed.hasSuffix(";") ? String(trimmed.dropLast()) : trimmed
        if withoutTrailingSemicolon.contains(";") {
            throw DatabaseAgentToolError.unsafeSQL("multiple statements are not allowed")
        }

        let first = withoutTrailingSemicolon
            .split(whereSeparator: { $0.isWhitespace || $0 == "(" })
            .first?
            .uppercased() ?? ""

        let allowed: Set<String>
        switch type {
        case .sqlite:
            allowed = ["SELECT", "PRAGMA", "EXPLAIN"]
        case .mysql:
            allowed = ["SELECT", "SHOW", "DESCRIBE", "EXPLAIN"]
        case .postgresql:
            allowed = ["SELECT", "EXPLAIN"]
        case .redis:
            allowed = []
        }

        guard allowed.contains(first) else {
            throw DatabaseAgentToolError.unsafeSQL("only read-only statements are allowed")
        }

        let upper = withoutTrailingSemicolon.uppercased()
        let forbidden = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE", "CREATE", "REPLACE", "GRANT", "REVOKE", "CALL", "COPY", "LOAD", "ATTACH", "DETACH"]
        if forbidden.contains(where: { upper.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }) {
            throw DatabaseAgentToolError.unsafeSQL("write or administrative keyword detected")
        }

        guard first == "SELECT", upper.range(of: "\\bLIMIT\\b", options: .regularExpression) == nil else {
            return withoutTrailingSemicolon
        }
        return "\(withoutTrailingSemicolon) LIMIT \(limit)"
    }

    public static func rowsAsDictionaries(_ result: QueryResult, limit: Int) -> DatabaseQueryPayload {
        let rows = Array(result.rows.prefix(limit)).map { row in
            row.map(valueString)
        }
        return DatabaseQueryPayload(
            columns: result.columns,
            rows: rows,
            rowsReturned: rows.count,
            rowsAffected: result.rowsAffected,
            truncated: result.rows.count > rows.count
        )
    }

    public static func quoteIdentifierPath(_ path: String, type: DatabaseType) -> String {
        path.split(separator: ".")
            .map { quoteIdentifier(String($0), type: type) }
            .joined(separator: ".")
    }

    public static func quoteIdentifier(_ identifier: String, type: DatabaseType) -> String {
        switch type {
        case .mysql:
            return "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
        case .sqlite, .postgresql, .redis:
            return "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
    }

    public static func valueString(_ value: DatabaseValue) -> String {
        let raw: String
        switch value {
        case .integer(let value):
            raw = String(value)
        case .double(let value):
            raw = String(value)
        case .string(let value):
            raw = value
        case .data(let value):
            raw = "<BLOB \(value.count) bytes>"
        case .bool(let value):
            raw = String(value)
        case .null:
            raw = "NULL"
        }

        guard raw.count > maxCellLength else { return raw }
        return String(raw.prefix(maxCellLength)) + "...(truncated)"
    }

    public static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    public static func encodeJSONObject(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}
