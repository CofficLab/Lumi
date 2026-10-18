import Foundation
import KitAgentTool

/// 回忆记忆工具：按 id 读取一条记忆。
public struct RecallMemoryTool: SuperAgentTool, @unchecked Sendable {
    public let name = "recall_memory"

    private let storage: MemoryFileStorage
    private let projectCapability: MemoryProjectCapability

    init(storage: MemoryFileStorage, projectCapability: MemoryProjectCapability) {
        self.storage = storage
        self.projectCapability = projectCapability
    }

    public func description(for language: LanguagePreference) -> String {
        "Recall a specific memory by its id from the persistent memory system."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Memory id to recall"],
                "scope": ["type": "string", "enum": ["global", "project"]],
            ],
            "required": ["id"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let id = MemoryToolSupport.string(arguments, "id") else { return "Recall memory" }
        return "回忆记忆：\(id)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let id = MemoryToolSupport.string(arguments, "id") else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "id is required")
        }
        let scope = MemoryToolSupport.scope(arguments)
        let projectPath = await MainActor.run { projectCapability.currentProjectPath }
        guard let item = try await storage.load(id: id, type: .project, scope: scope, projectPath: scope == .project ? projectPath : nil) else {
            return "## Memory Not Found ❌\n\n**ID**: `\(id)`"
        }
        return item.formattedContent(staleThresholdDays: 30)
    }
}
