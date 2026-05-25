import AgentToolKit
import Foundation
import MemoryKit

/// 保存记忆工具。
///
/// 允许 AI 助手将重要信息保存到持久化记忆系统中。
/// 核心原则：只记从代码/Git 推导不出来的信息。
public struct SaveMemoryTool: SuperAgentTool {
    public let name = "save_memory"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "保存一条记忆到持久化记忆系统。记忆应该是非显而易见的、无法从代码或 Git 历史推导的信息。不要保存代码模式、架构或文档中已有的内容。"
        case .english:
            return "Save a memory to the persistent memory system. Memories should be non-obvious information that cannot be derived from code or Git history. Do not save code patterns, architecture, or already-documented content."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let typeDesc: String
        switch language {
        case .chinese:
            typeDesc = "记忆类型：user（用户偏好）、feedback（行为指导）、project（项目上下文）、reference（外部系统指针）"
        case .english:
            typeDesc = "Memory type: user (user preferences), feedback (behavioral guidance), project (project context), reference (external system pointers)"
        }

        let scopeDesc: String
        switch language {
        case .chinese:
            scopeDesc = "作用域：global（跨项目通用）或 project（当前项目专属）。user 和 feedback 类型通常用 global，project 和 reference 类型通常用 project"
        case .english:
            scopeDesc = "Scope: global (cross-project) or project (current project only). user and feedback types typically use global, project and reference types typically use project"
        }

        return [
            "type": "object",
            "properties": [
                "id": [
                    "type": "string",
                    "description": "Unique identifier for this memory (kebab-case, e.g., 'user-role', 'feedback-no-summary')",
                ],
                "type": [
                    "type": "string",
                    "enum": ["user", "feedback", "project", "reference"],
                    "description": typeDesc,
                ],
                "name": [
                    "type": "string",
                    "description": "Short, human-readable name for this memory",
                ],
                "description": [
                    "type": "string",
                    "description": "One-line description used to determine relevance in future conversations. Be specific.",
                ],
                "content": [
                    "type": "string",
                    "description": "Full memory content. For feedback/project types, structure as: rule/fact, then **Why:** and **How to apply:** lines",
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
            "required": ["id", "type", "name", "description", "content"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "保存记忆"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let id = arguments["id"]?.value as? String, !id.isEmpty else {
            throw MemoryToolError.missingArgument("id")
        }
        guard let typeRaw = arguments["type"]?.value as? String, let type = MemoryType(rawValue: typeRaw) else {
            throw MemoryToolError.invalidArgument("type must be one of: user, feedback, project, reference")
        }
        guard let name = arguments["name"]?.value as? String, !name.isEmpty else {
            throw MemoryToolError.missingArgument("name")
        }
        guard let description = arguments["description"]?.value as? String, !description.isEmpty else {
            throw MemoryToolError.missingArgument("description")
        }
        guard let content = arguments["content"]?.value as? String, !content.isEmpty else {
            throw MemoryToolError.missingArgument("content")
        }

        let scopeRaw = arguments["scope"]?.value as? String ?? "global"
        let scope: MemoryScope
        if scopeRaw == "project" {
            guard let projectPath = arguments["project_path"]?.value as? String, !projectPath.isEmpty else {
                throw MemoryToolError.missingArgument("project_path is required when scope=project")
            }
            scope = .project(projectPath)
        } else {
            scope = .global
        }

        do {
            let item = try await MemoryStorageService.shared.createMemory(
                id: id,
                type: type,
                name: name,
                description: description,
                content: content,
                scope: scope
            )

            return "✅ Memory saved: **\(item.name)** (\(item.type.rawValue), \(scopeRaw))\n\nUse `list_memories` to view all memories or `recall_memory` to search for specific memories."
        } catch {
            return "Error saving memory: \(error.localizedDescription)"
        }
    }
}
