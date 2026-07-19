import Foundation
import LumiKernel

/// 列出记忆工具。
///
/// 列出指定作用域下的所有记忆。
public struct ListMemoriesTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "list_memories",
        displayName: "List Memories",
        description: "List all saved memories. Can filter by scope."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "scope": .object([
                    "type": .string("string"),
                    "enum": .array([.string("global"), .string("project"), .string("all")]),
                    "description": .string("Filter scope: global (global memories), project (current project memories), or all (both). Defaults to all"),
                ]),
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Required when scope=project. The absolute path to the current project."),
                ]),
            ]),
            "required": .array([]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "列出记忆"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let scopeRaw = try MemoryToolInput.scope(
            arguments["scope"]?.anyValue,
            default: "all",
            allowed: ["global", "project", "all"]
        )

        var globalMemories: [MemoryItem] = []
        var projectMemories: [MemoryItem] = []

        switch scopeRaw {
        case "global":
            globalMemories = await MemoryStorageService.shared.listMemories(scope: .global)
        case "project":
            guard let projectPath = MemoryToolInput.string(arguments["project_path"]?.anyValue) else {
                throw MemoryToolError.missingArgument("project_path is required when scope=project")
            }
            projectMemories = await MemoryStorageService.shared.listMemories(scope: .project(projectPath))
        default: // "all"
            globalMemories = await MemoryStorageService.shared.listMemories(scope: .global)
            if let projectPath = MemoryToolInput.string(arguments["project_path"]?.anyValue) {
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
