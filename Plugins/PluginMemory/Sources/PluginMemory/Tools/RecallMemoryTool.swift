import AgentToolKit
import Foundation
import MemoryKit

/// 检索记忆工具。
///
/// 根据查询文本检索相关记忆。
public struct RecallMemoryTool: SuperAgentTool {
    public let name = "recall_memory"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "检索与查询相关的记忆。当你需要回忆过往对话中讨论的内容时使用。"
        case .english:
            return "Search for memories related to a query. Use when you need to recall content discussed in previous conversations."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let scopeDesc: String
        switch language {
        case .chinese:
            scopeDesc = "搜索范围：global（全局记忆）或 project（当前项目记忆）。默认为 global"
        case .english:
            scopeDesc = "Search scope: global (global memories) or project (current project memories). Defaults to global"
        }

        return [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "The search query to find relevant memories",
                ],
                "scope": [
                    "type": "string",
                    "enum": ["global", "project"],
                    "description": scopeDesc,
                ],
                "project_path": [
                    "type": "string",
                    "description": "Required when scope=project. The absolute path to the current project.",
                ],
                "max_results": [
                    "type": "integer",
                    "description": "Maximum number of results to return (default: 5, max: 20)",
                    "minimum": MemoryToolInput.minMaxResults,
                    "maximum": MemoryToolInput.maxMaxResults,
                ],
            ],
            "required": ["query"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "检索记忆"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let query = MemoryToolInput.string(arguments["query"]?.value) else {
            throw MemoryToolError.missingArgument("query")
        }

        let scopeRaw = try MemoryToolInput.scope(
            arguments["scope"]?.value,
            default: "global",
            allowed: ["global", "project"]
        )
        let scope: MemoryScope
        if scopeRaw == "project" {
            guard let projectPath = MemoryToolInput.string(arguments["project_path"]?.value) else {
                throw MemoryToolError.missingArgument("project_path is required when scope=project")
            }
            scope = .project(projectPath)
        } else {
            scope = .global
        }

        let cappedMax = MemoryToolInput.maxResults(arguments["max_results"]?.value)

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
