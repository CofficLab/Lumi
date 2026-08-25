import Foundation
import KitAgentTool
import ProviderProject

/// 记忆工具共享：解析 scope/type/projectPath 参数。
enum MemoryToolSupport {
    static func scope(_ arguments: [String: ToolArgument]) -> MemoryScope {
        guard let raw = arguments["scope"]?.value as? String else { return .global }
        return MemoryScope(rawValue: raw) ?? .global
    }

    static func type(_ arguments: [String: ToolArgument]) -> MemoryType? {
        guard let raw = arguments["type"]?.value as? String else { return nil }
        return MemoryType(rawValue: raw)
    }

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        (arguments[key]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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

/// 回忆记忆工具：按 id 读取一条记忆。
public struct RecallMemoryTool: SuperAgentTool, @unchecked Sendable {
    public let name = "recall_memory"

    private let storage: MemoryFileStorage
    private let project: (any ProjectProviding)?

    public init(storage: MemoryFileStorage, project: (any ProjectProviding)?) {
        self.storage = storage
        self.project = project
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
        let projectPath = await MainActor.run { project?.currentProject?.path }
        guard let item = try await storage.load(id: id, type: .project, scope: scope, projectPath: scope == .project ? projectPath : nil) else {
            return "## Memory Not Found ❌\n\n**ID**: `\(id)`"
        }
        return item.formattedContent(staleThresholdDays: 30)
    }
}

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
