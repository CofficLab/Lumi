import Foundation
import KitAgentTool

/// 列出记忆工具。
public struct ListMemoriesTool: SuperAgentTool, @unchecked Sendable {
    public let name = "list_memories"

    private let storage: MemoryFileStorage
    private let projectCapability: MemoryProjectCapability

    init(storage: MemoryFileStorage, projectCapability: MemoryProjectCapability) {
        self.storage = storage
        self.projectCapability = projectCapability
    }

    public func description(for language: LanguagePreference) -> String {
        "List saved memories to find what is available."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "scope": ["type": "string", "enum": ["global", "project"]],
            ],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "列出记忆"
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(
            arguments: arguments,
            conversationProjectPath: await context.conversationProjectPath()
        ))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(arguments: arguments, conversationProjectPath: nil)
    }

    private func execute(
        arguments: [String: ToolArgument],
        conversationProjectPath: String?
    ) async throws -> String {
        let scope = MemoryToolSupport.scope(arguments)
        let projectPath = await MemoryToolSupport.resolveProjectPath(
            conversationProjectPath: conversationProjectPath,
            capability: projectCapability
        )
        let items = await storage.list(scope: scope, projectPath: scope == .project ? projectPath : nil)
        guard !items.isEmpty else { return "暂无保存的记忆（\(scope.rawValue)）" }
        return items.map { "• `\($0.id)` — \($0.name)（\($0.type.rawValue)）" }.joined(separator: "\n")
    }
}
