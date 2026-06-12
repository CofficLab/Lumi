import AgentToolKit
import Foundation

/// 删除记忆工具。
///
/// 从持久化记忆系统中删除指定记忆。
public struct DeleteMemoryTool: SuperAgentTool {
    public let name = "delete_memory"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "从持久化记忆系统中删除指定记忆。删除后无法恢复。"
        case .english:
            return "Delete a memory from the persistent memory system. Deletion is irreversible."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let scopeDesc: String
        switch language {
        case .chinese:
            scopeDesc = "删除范围：global（全局记忆）或 project（当前项目记忆）。默认为 global"
        case .english:
            scopeDesc = "Delete scope: global (global memories) or project (current project memories). Defaults to global"
        }

        return [
            "type": "object",
            "properties": [
                "id": [
                    "type": "string",
                    "description": "The ID of the memory to delete",
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
            ],
            "required": ["id"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "删除记忆"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let id = MemoryToolInput.string(arguments["id"]?.value) else {
            throw MemoryToolError.missingArgument("id")
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

        do {
            let memory = try await MemoryStorageService.shared.readMemory(id: id, scope: scope)
            try await MemoryStorageService.shared.deleteMemory(id: id, scope: scope)

            return "✅ Memory deleted: **\(memory.name)** (\(memory.type.rawValue))"
        } catch {
            return "Error deleting memory '\(id)': \(error.localizedDescription). Use `list_memories` to see available memories."
        }
    }
}
