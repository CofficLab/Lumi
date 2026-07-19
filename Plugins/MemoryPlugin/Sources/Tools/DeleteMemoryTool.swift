import Foundation
import LumiKernel

/// 删除记忆工具。
///
/// 从持久化记忆系统中删除指定记忆。
public struct DeleteMemoryTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "delete_memory",
        displayName: "Delete Memory",
        description: "Delete a memory from the persistent memory system. Deletion is irreversible."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the memory to delete"),
                ]),
                "scope": .object([
                    "type": .string("string"),
                    "enum": .array([.string("global"), .string("project")]),
                    "description": .string("Delete scope: global (global memories) or project (current project memories). Defaults to global"),
                ]),
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Required when scope=project. The absolute path to the current project."),
                ]),
            ]),
            "required": .array([.string("id")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "删除记忆"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let id = MemoryToolInput.string(arguments["id"]?.anyValue) else {
            throw MemoryToolError.missingArgument("id")
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

        do {
            let memory = try await MemoryStorageService.shared.readMemory(id: id, scope: scope)
            try await MemoryStorageService.shared.deleteMemory(id: id, scope: scope)

            return "✅ Memory deleted: **\(memory.name)** (\(memory.type.rawValue))"
        } catch {
            return "Error deleting memory '\(id)': \(error.localizedDescription). Use `list_memories` to see available memories."
        }
    }
}
