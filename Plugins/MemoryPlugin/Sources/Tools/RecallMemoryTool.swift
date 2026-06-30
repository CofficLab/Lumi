import Foundation
import LumiCoreKit

/// 检索记忆工具。
///
/// 根据查询文本检索相关记忆。
public struct RecallMemoryTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "recall_memory",
        displayName: "Recall Memory",
        description: "Search for memories related to a query. Use when you need to recall content discussed in previous conversations."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("The search query to find relevant memories"),
                ]),
                "scope": .object([
                    "type": .string("string"),
                    "enum": .array([.string("global"), .string("project")]),
                    "description": .string("Search scope: global (global memories) or project (current project memories). Defaults to global"),
                ]),
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Required when scope=project. The absolute path to the current project."),
                ]),
                "max_results": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of results to return (default: 5, max: 20)"),
                    "minimum": .int(MemoryToolInput.minMaxResults),
                    "maximum": .int(MemoryToolInput.maxMaxResults),
                ]),
            ]),
            "required": .array([.string("query")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "检索记忆"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let query = MemoryToolInput.string(arguments["query"]?.anyValue) else {
            throw MemoryToolError.missingArgument("query")
        }

        let scopeRaw = try MemoryToolInput.scope(
            arguments["scope"]?.anyValue,
            default: "global",
            allowed: ["global", "project"]
        )
        let scope: MemoryScope
        if scopeRaw == "project" {
            guard let projectPath = MemoryToolInput.string(arguments["project_path"]?.anyValue) else {
                throw MemoryToolError.missingArgument("project_path is required when scope=project")
            }
            scope = .project(projectPath)
        } else {
            scope = .global
        }

        let cappedMax = MemoryToolInput.maxResults(arguments["max_results"]?.anyValue)

        let memories = await MemoryRetrievalService.shared.findRelevant(
            query: query,
            scope: scope,
            maxResults: cappedMax
        )

        guard !memories.isEmpty else {
            return "No memories found for query: \"\(query)\". Use `save_memory` to create new memories."
        }

        var lines: [String] = []
        lines.append("Found \(memories.count) relevant memories for \"\(query)\":")
        lines.append("")

        let staleThreshold = MemoryPlugin.config.staleThresholdDays
        for memory in memories {
            lines.append(memory.formattedContent(staleThresholdDays: staleThreshold))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
