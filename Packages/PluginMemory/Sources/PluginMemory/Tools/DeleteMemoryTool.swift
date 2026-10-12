import Foundation
import KitAgentTool
import ProviderProject

/// 删除记忆工具。
public struct DeleteMemoryTool: SuperAgentTool, @unchecked Sendable {
    public let name = "delete_memory"

    private let storage: MemoryFileStorage
    private let project: (any ProjectProviding)?

    public init(storage: MemoryFileStorage, project: (any ProjectProviding)?) {
        self.storage = storage
        self.project = project
    }

    public func description(for language: LanguagePreference) -> String {
        "Delete a memory by its id."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Memory id to delete"],
                "scope": ["type": "string", "enum": ["global", "project"]],
            ],
            "required": ["id"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let id = MemoryToolSupport.string(arguments, "id") else { return "Delete memory" }
        return "删除记忆：\(id)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let id = MemoryToolSupport.string(arguments, "id") else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "id is required")
        }
        let scope = MemoryToolSupport.scope(arguments)
        let projectPath = await MainActor.run { project?.currentProject?.path }
        try await storage.delete(id: id, scope: scope, projectPath: scope == .project ? projectPath : nil)
        return "## Memory Deleted ✅\n\n**ID**: `\(id)`"
    }
}
