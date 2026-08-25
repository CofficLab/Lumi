import KitAgentTool
import Foundation

/// KernelCore adapters for the stable database Agent tool contract.
public struct DatabaseListConnectionsV2Tool: SuperAgentTool {
    public static let toolName = "database_list_connections"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "List database connections available to Agent database tools. Passwords and secrets are never returned." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": [:]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "List database connections" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String { try await DatabaseAgentToolService.shared.listConnections() }
}

public struct DatabaseDescribeSchemaV2Tool: SuperAgentTool {
    public static let toolName = "database_describe_schema"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Describe tables, columns, or key samples for an Agent-accessible database connection." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { DatabaseV2ToolSupport.schema(properties: ["connection_id": DatabaseV2ToolSupport.string("Connection UUID returned by database_list_connections"), "limit": DatabaseV2ToolSupport.integer("Maximum entries to return; default 100, maximum 1000.")], required: ["connection_id"]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Describe database schema" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String { try await DatabaseAgentToolService.shared.describeSchema(connectionId: DatabaseV2ToolSupport.connectionID(arguments), limit: DatabaseV2ToolSupport.limit(arguments)) }
}

public struct DatabaseReadonlyQueryV2Tool: SuperAgentTool {
    public static let toolName = "database_query_readonly"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Run a read-only SQL query. Mutating and administrative statements are rejected." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { DatabaseV2ToolSupport.schema(properties: ["connection_id": DatabaseV2ToolSupport.string("Connection UUID returned by database_list_connections"), "sql": DatabaseV2ToolSupport.string("Read-only SQL."), "limit": DatabaseV2ToolSupport.integer("Maximum result rows; default 100, maximum 1000.")], required: ["connection_id", "sql"]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Run read-only database query" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String { try await DatabaseAgentToolService.shared.queryReadonly(connectionId: DatabaseV2ToolSupport.connectionID(arguments), sql: try DatabaseV2ToolSupport.requiredString(arguments, "sql"), limit: DatabaseV2ToolSupport.limit(arguments)) }
}

public struct DatabaseSampleTableV2Tool: SuperAgentTool {
    public static let toolName = "database_sample_table"
    public let name = Self.toolName
    public init() {}
    public func description(for language: LanguagePreference) -> String { "Return a small sample from a table using safe identifier quoting." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { DatabaseV2ToolSupport.schema(properties: ["connection_id": DatabaseV2ToolSupport.string("Connection UUID returned by database_list_connections"), "table": DatabaseV2ToolSupport.string("Table name, optionally schema-qualified."), "limit": DatabaseV2ToolSupport.integer("Maximum result rows; default 100, maximum 1000.")], required: ["connection_id", "table"]) }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Sample database table" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String { try await DatabaseAgentToolService.shared.sampleTable(connectionId: DatabaseV2ToolSupport.connectionID(arguments), table: try DatabaseV2ToolSupport.requiredString(arguments, "table"), limit: DatabaseV2ToolSupport.limit(arguments)) }
}

private enum DatabaseV2ToolSupport {
    static func schema(properties: [String: Any], required: [String]) -> [String: Any] { ["type": "object", "properties": properties, "required": required] }
    static func string(_ description: String) -> [String: String] { ["type": "string", "description": description] }
    static func integer(_ description: String) -> [String: String] { ["type": "integer", "description": description] }
    static func connectionID(_ arguments: [String: ToolArgument]) throws -> UUID { try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.value) }
    static func limit(_ arguments: [String: ToolArgument]) throws -> Int { try DatabaseAgentToolService.normalizedLimit(arguments["limit"]?.value) }
    static func requiredString(_ arguments: [String: ToolArgument], _ key: String) throws -> String {
        guard let value = arguments[key]?.value as? String, !value.isEmpty else { throw DatabaseAgentToolError.missingArgument(key) }
        return value
    }
}
