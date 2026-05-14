import Foundation

private enum DatabaseToolArguments {
    static func string(_ name: String, from arguments: [String: ToolArgument]) throws -> String {
        guard let value = arguments[name]?.value as? String, !value.isEmpty else {
            throw DatabaseAgentToolError.missingArgument(name)
        }
        return value
    }

    static func limit(from arguments: [String: ToolArgument]) throws -> Int {
        try DatabaseAgentToolService.normalizedLimit(arguments["limit"]?.value)
    }
}

struct DatabaseListConnectionsTool: SuperAgentTool {
    let name = "database_list_connections"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "List database connections that are available to Agent database tools. Passwords and secrets are never returned."
        case .english:
            return "List database connections that are available to Agent database tools. Passwords and secrets are never returned."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await DatabaseAgentToolService.shared.listConnections()
    }
}

struct DatabaseDescribeSchemaTool: SuperAgentTool {
    let name = "database_describe_schema"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Describe tables, columns, or key samples for an Agent-accessible database connection. Use this before writing a read-only query."
        case .english:
            return "Describe tables, columns, or key samples for an Agent-accessible database connection. Use this before writing a read-only query."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "connection_id": [
                    "type": "string",
                    "description": "Connection UUID returned by database_list_connections"
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum rows or schema entries to return. Default 100, maximum 1000."
                ],
            ],
            "required": ["connection_id"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let id = try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.value)
        let limit = try DatabaseToolArguments.limit(from: arguments)
        return try await DatabaseAgentToolService.shared.describeSchema(connectionId: id, limit: limit)
    }
}

struct DatabaseReadonlyQueryTool: SuperAgentTool {
    let name = "database_query_readonly"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Run a read-only SQL query against an Agent-accessible SQL database. Only SELECT, schema inspection, and explain-style statements are accepted. Results are limited and truncated."
        case .english:
            return "Run a read-only SQL query against an Agent-accessible SQL database. Only SELECT, schema inspection, and explain-style statements are accepted. Results are limited and truncated."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "connection_id": [
                    "type": "string",
                    "description": "Connection UUID returned by database_list_connections"
                ],
                "sql": [
                    "type": "string",
                    "description": "Read-only SQL. Mutating or administrative statements are rejected."
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum result rows. Default 100, maximum 1000."
                ],
            ],
            "required": ["connection_id", "sql"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let id = try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.value)
        let sql = try DatabaseToolArguments.string("sql", from: arguments)
        let limit = try DatabaseToolArguments.limit(from: arguments)
        return try await DatabaseAgentToolService.shared.queryReadonly(connectionId: id, sql: sql, limit: limit)
    }
}

struct DatabaseSampleTableTool: SuperAgentTool {
    let name = "database_sample_table"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Return a small sample from a table using safe identifier quoting. Prefer this over writing SELECT * by hand."
        case .english:
            return "Return a small sample from a table using safe identifier quoting. Prefer this over writing SELECT * by hand."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "connection_id": [
                    "type": "string",
                    "description": "Connection UUID returned by database_list_connections"
                ],
                "table": [
                    "type": "string",
                    "description": "Table name, optionally schema-qualified"
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum result rows. Default 100, maximum 1000."
                ],
            ],
            "required": ["connection_id", "table"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let id = try DatabaseAgentToolService.connectionId(from: arguments["connection_id"]?.value)
        let table = try DatabaseToolArguments.string("table", from: arguments)
        let limit = try DatabaseToolArguments.limit(from: arguments)
        return try await DatabaseAgentToolService.shared.sampleTable(connectionId: id, table: table, limit: limit)
    }
}

@MainActor
struct DatabaseAgentToolFactory: SuperAgentToolFactory {
    let id = "database.agent.tools.factory"
    let order = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [SuperAgentTool] {
        [
            DatabaseListConnectionsTool(),
            DatabaseDescribeSchemaTool(),
            DatabaseReadonlyQueryTool(),
            DatabaseSampleTableTool(),
        ]
    }
}
