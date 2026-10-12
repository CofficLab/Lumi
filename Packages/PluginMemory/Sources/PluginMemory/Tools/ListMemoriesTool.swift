import Foundation
import KitAgentTool
import ProviderProject

/// 列出记忆工具。
public struct ListMemoriesTool: SuperAgentTool, @unchecked Sendable {
    public let name = "list_memories"

    private let storage: MemoryFileStorage
    private let project: (any ProjectProviding)?

    public init(storage: MemoryFileStorage, project: (any ProjectProviding)?) {
        self.storage = storage
        self.project = project
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

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = MemoryToolSupport.scope(arguments)
        let projectPath = await MainActor.run { project?.currentProject?.path }
        let items = await storage.list(scope: scope, projectPath: scope == .project ? projectPath : nil)
        guard !items.isEmpty else { return "暂无保存的记忆（\(scope.rawValue)）" }
        return items.map { "• `\($0.id)` — \($0.name)（\($0.type.rawValue)）" }.joined(separator: "\n")
    }
}
