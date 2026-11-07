import Foundation
import KitAgentTool

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
    /// 每个连接建立时使用的配置快照，用于判断是否可以复用。
    private var connectedConfigs: [UUID: DatabaseConfig] = [:]

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

    /// 描述连接的表结构。
    ///
    /// - Parameter schemaName: 只描述某个 schema（PostgreSQL）。为空时描述全部非系统 schema。
    public func describeSchema(connectionId: UUID, limit: Int, schemaName: String? = nil) async throws -> String {
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
            // 不写死 public：应用表常在 analytics 之类的普通 schema 里。
            // 未指定 schema 时列出所有非系统 schema。
            let requested = schemaName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasRequested = !(requested?.isEmpty ?? true)
            let (schemaSQL, params) = Self.postgresSchemaFilter(schema: requested)
            let result = try await connection.query(
                """
                SELECT table_schema, table_name, column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE true \(schemaSQL)
                ORDER BY table_schema, table_name, ordinal_position
                LIMIT \(limit)
                """,
                params: params.isEmpty ? nil : params
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
        // 连接必须与建立时的配置一致；配置被编辑（同一 id 换库/换地址）后，
        // 直接复用旧连接会继续读写编辑前的位置。
        if connectedConfigs[config.id] == config,
           let connection = await manager.getConnection(for: config.id),
           await connection.isAlive() {
            return connection
        }
        let connection = try await manager.connect(config: config)
        connectedConfigs[config.id] = config
        return connection
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
        guard let int = ToolArgumentNumber.int(value) else {
            throw DatabaseAgentToolError.invalidLimit
        }
        return try normalizedLimit(int)
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

        // 判定用「代码骨架」：字符串字面量与注释里的内容不是代码。
        // `SELECT 'DROP' AS word` 是合法读取，`SELECT 1; DROP TABLE t` 才是写操作。
        // 执行用的仍是原始 SQL —— 骨架只用于判断，绝不替代语句本身。
        let skeleton = SQLStatementParser.stripLiteralsAndComments(trimmed)
        let skeletonWithoutTrailingSemicolon = skeleton.hasSuffix(";") ? String(skeleton.dropLast()) : skeleton
        if skeletonWithoutTrailingSemicolon.contains(";") {
            throw DatabaseAgentToolError.unsafeSQL("multiple statements are not allowed")
        }

        let first = skeletonWithoutTrailingSemicolon
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

        let upper = skeletonWithoutTrailingSemicolon.uppercased()
        let forbidden = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE", "CREATE", "REPLACE", "GRANT", "REVOKE", "CALL", "COPY", "LOAD", "ATTACH", "DETACH"]
        if forbidden.contains(where: { upper.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }) {
            throw DatabaseAgentToolError.unsafeSQL("write or administrative keyword detected")
        }

        // 返回给执行层的是原始 SQL：字面量与注释必须原样保留。
        let statement = trimmed.hasSuffix(";") ? String(trimmed.dropLast()) : trimmed

        guard first == "SELECT", upper.range(of: "\\bLIMIT\\b", options: .regularExpression) == nil else {
            return statement
        }
        return "\(statement) LIMIT \(limit)"
    }

    /// PostgreSQL schema 过滤条件。
    ///
    /// - 指定 schema 时用绑定参数 `$1`（不拼进 SQL，避免注入）；
    /// - 未指定时列出所有非系统 schema —— 应用表常在 analytics 之类的普通 schema 里，
    ///   写死 public 会让这些表完全无法被发现。
    static func postgresSchemaFilter(schema: String?) -> (sql: String, params: [DatabaseValue]) {
        let trimmed = schema?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return (
                "AND table_schema NOT IN ('pg_catalog', 'information_schema')",
                []
            )
        }
        return ("AND table_schema = $1", [.string(trimmed)])
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
