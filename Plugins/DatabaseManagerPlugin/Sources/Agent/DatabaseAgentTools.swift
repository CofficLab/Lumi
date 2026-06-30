import Foundation
import LumiCoreKit
import SuperLogKit

public struct DatabaseListConnectionsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔌"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "database_list_connections",
        displayName: LumiPluginLocalization.string("List Database Connections", bundle: .module),
        description: LumiPluginLocalization.string("List database connections that are available to Agent database tools. Passwords and secrets are never returned.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "列出数据库连接" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try await DatabaseAgentToolService.shared.listConnections()
    }
}

public struct DatabaseDescribeSchemaTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "database_describe_schema",
        displayName: LumiPluginLocalization.string("Describe Schema", bundle: .module),
        description: LumiPluginLocalization.string("Describe tables, columns, or key samples for an Agent-accessible database connection. Use this before writing a read-only query.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "connection_id": .object([
                    "type": .string("string"),
                    "description": .string("Connection UUID returned by database_list_connections")
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum rows or schema entries to return. Default 100, maximum 1000.")
                ])
            ]),
            "required": .array([.string("connection_id")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "查看数据库结构" }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let id = try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.anyValue)
        let limit = try DatabaseAgentToolService.normalizedLimit(arguments["limit"]?.anyValue)
        return try await DatabaseAgentToolService.shared.describeSchema(connectionId: id, limit: limit)
    }
}

public struct DatabaseReadonlyQueryTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "database_query_readonly",
        displayName: LumiPluginLocalization.string("Query Readonly", bundle: .module),
        description: LumiPluginLocalization.string("Run a read-only SQL query against an Agent-accessible SQL database. Only SELECT, schema inspection, and explain-style statements are accepted. Results are limited and truncated.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "connection_id": .object([
                    "type": .string("string"),
                    "description": .string("Connection UUID returned by database_list_connections")
                ]),
                "sql": .object([
                    "type": .string("string"),
                    "description": .string("Read-only SQL. Mutating or administrative statements are rejected.")
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum result rows. Default 100, maximum 1000.")
                ])
            ]),
            "required": .array([.string("connection_id"), .string("sql")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "执行只读数据库查询" }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let id = try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.anyValue)
        guard let sql = arguments["sql"]?.stringValue, !sql.isEmpty else {
            throw DatabaseAgentToolError.missingArgument("sql")
        }
        let limit = try DatabaseAgentToolService.normalizedLimit(arguments["limit"]?.anyValue)
        return try await DatabaseAgentToolService.shared.queryReadonly(connectionId: id, sql: sql, limit: limit)
    }
}

public struct DatabaseSampleTableTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "database_sample_table",
        displayName: LumiPluginLocalization.string("Sample Table", bundle: .module),
        description: LumiPluginLocalization.string("Return a small sample from a table using safe identifier quoting. Prefer this over writing SELECT * by hand.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "connection_id": .object([
                    "type": .string("string"),
                    "description": .string("Connection UUID returned by database_list_connections")
                ]),
                "table": .object([
                    "type": .string("string"),
                    "description": .string("Table name, optionally schema-qualified")
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum result rows. Default 100, maximum 1000.")
                ])
            ]),
            "required": .array([.string("connection_id"), .string("table")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "查看数据库表样本" }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let id = try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.anyValue)
        guard let table = arguments["table"]?.stringValue, !table.isEmpty else {
            throw DatabaseAgentToolError.missingArgument("table")
        }
        let limit = try DatabaseAgentToolService.normalizedLimit(arguments["limit"]?.anyValue)
        return try await DatabaseAgentToolService.shared.sampleTable(connectionId: id, table: table, limit: limit)
    }
}
