import Foundation
import KitAgentTool
import ProviderProject

/// 保存记忆工具：把重要信息写入持久化记忆系统。
public struct SaveMemoryTool: SuperAgentTool, @unchecked Sendable {
    public let name = "save_memory"

    private let storage: MemoryFileStorage
    private let project: (any ProjectProviding)?

    public init(storage: MemoryFileStorage, project: (any ProjectProviding)?) {
        self.storage = storage
        self.project = project
    }

    public func description(for language: LanguagePreference) -> String {
        "Save a memory to the persistent memory system. Save when you discover something valuable that is not obvious: user preferences and workflows, project conventions, feedback about behavior, recurring patterns, lessons learned from debugging."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "Unique kebab-case identifier, e.g. 'user-role'"],
                "type": ["type": "string", "enum": ["user", "feedback", "project", "reference"], "description": "Memory type"],
                "name": ["type": "string", "description": "Short human-readable name"],
                "description": ["type": "string", "description": "One-line relevance description"],
                "content": ["type": "string", "description": "Full memory content. For feedback/project: rule/fact, **Why:**, **How to apply:** lines"],
                "scope": ["type": "string", "enum": ["global", "project"]],
            ],
            "required": ["id", "name", "content"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let name = MemoryToolSupport.string(arguments, "name") else { return "Save memory" }
        return "保存记忆：\(name)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let id = MemoryToolSupport.string(arguments, "id"),
              let name = MemoryToolSupport.string(arguments, "name"),
              let content = MemoryToolSupport.string(arguments, "content"),
              !id.isEmpty, !content.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "id, name and content are required")
        }
        let type = MemoryToolSupport.type(arguments) ?? .project
        let scope = MemoryToolSupport.scope(arguments)
        let description = MemoryToolSupport.string(arguments, "description") ?? ""
        let projectPath = await MainActor.run { project?.currentProject?.path }

        let item = try await storage.save(
            id: id,
            type: type,
            name: name,
            description: description,
            content: content,
            scope: scope,
            projectPath: scope == .project ? projectPath : nil
        )
        return "## Memory Saved ✅\n\n**ID**: `\(item.id)`\n**Type**: \(item.type.rawValue)\n**Scope**: \(scope.rawValue)"
    }
}
