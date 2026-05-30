import AgentToolKit
import Foundation
import MemoryKit

/// 列出记忆工具。
///
/// 列出指定作用域下的所有记忆。
public struct ListMemoriesTool: SuperAgentTool {
    public let name = "list_memories"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出所有已保存的记忆。可以按作用域过滤。"
        case .english:
            return "List all saved memories. Can filter by scope."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let scopeDesc: String
        switch language {
        case .chinese:
            scopeDesc = "过滤范围：global（全局记忆）、project（当前项目记忆）或 all（全部）。默认为 all"
        case .english:
            scopeDesc = "Filter scope: global (global memories), project (current project memories), or all (both). Defaults to all"
        }

        return [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": ["global", "project", "all"],
                    "description": scopeDesc,
                ],
                "project_path": [
                    "type": "string",
                    "description": "Required when scope=project. The absolute path to the current project.",
                ],
            ],
            "required": [],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "列出记忆"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let scopeRaw = try MemoryToolInput.scope(
            arguments["scope"]?.value,
            default: "all",
            allowed: ["global", "project", "all"]
        )

        var globalMemories: [MemoryItem] = []
        var projectMemories: [MemoryItem] = []

        switch scopeRaw {
        case "global":
            globalMemories = await MemoryStorageService.shared.listMemories(scope: .global)
        case "project":
            guard let projectPath = MemoryToolInput.string(arguments["project_path"]?.value) else {
                throw MemoryToolError.missingArgument("project_path is required when scope=project")
            }
            projectMemories = await MemoryStorageService.shared.listMemories(scope: .project(projectPath))
        default: // "all"
            globalMemories = await MemoryStorageService.shared.listMemories(scope: .global)
            if let projectPath = MemoryToolInput.string(arguments["project_path"]?.value) {
                projectMemories = await MemoryStorageService.shared.listMemories(scope: .project(projectPath))
            }
        }

        if globalMemories.isEmpty && projectMemories.isEmpty {
            return "No memories found. Use `save_memory` to create your first memory."
        }

        let staleThreshold = MemoryPlugin.config.staleThresholdDays

        var lines: [String] = []
        lines.append("## Memories")
        lines.append("")

        if !globalMemories.isEmpty {
            lines.append("### Global Memories (\(globalMemories.count))")
            lines.append("")
            lines.append("| ID | Type | Name | Description | Updated |")
            lines.append("|----|------|------|-------------|---------|")
            for memory in globalMemories {
                let staleTag = memory.ageInDays > staleThreshold ? " ⚠️" : ""
                lines.append("| \(memory.id) | \(memory.type.rawValue) | \(memory.name) | \(memory.description) | \(memory.ageInDays)d ago\(staleTag) |")
            }
            lines.append("")
        }

        if !projectMemories.isEmpty {
            lines.append("### Project Memories (\(projectMemories.count))")
            lines.append("")
            lines.append("| ID | Type | Name | Description | Updated |")
            lines.append("|----|------|------|-------------|---------|")
            for memory in projectMemories {
                let staleTag = memory.ageInDays > staleThreshold ? " ⚠️" : ""
                lines.append("| \(memory.id) | \(memory.type.rawValue) | \(memory.name) | \(memory.description) | \(memory.ageInDays)d ago\(staleTag) |")
            }
            lines.append("")
        }

        lines.append("Use `save_memory` to create, `delete_memory` to remove, or `recall_memory` to search for specific memories.")

        return lines.joined(separator: "\n")
    }
}
