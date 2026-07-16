import Foundation
import LumiCoreKit

/// 保存记忆工具。
///
/// 允许 AI 助手将重要信息保存到持久化记忆系统中。
/// 核心原则：只记从代码/Git 推导不出来的信息。
public struct SaveMemoryTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "save_memory",
        displayName: "Save Memory",
        description: "Save a memory to the persistent memory system. You should proactively save important information that helps you provide better assistance in future conversations, such as: user preferences and workflows, project-specific conventions and practices, feedback about your behavior or output style, recurring patterns in user requests, and lessons learned from debugging sessions. Save when you discover something valuable that is not obvious from the current context."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("Unique identifier for this memory (kebab-case, e.g., 'user-role', 'feedback-no-summary')"),
                ]),
                "type": .object([
                    "type": .string("string"),
                    "enum": .array([.string("user"), .string("feedback"), .string("project"), .string("reference")]),
                    "description": .string("Memory type: user (user preferences), feedback (behavioral guidance), project (project context), reference (external system pointers)"),
                ]),
                "name": .object([
                    "type": .string("string"),
                    "description": .string("Short, human-readable name for this memory"),
                ]),
                "description": .object([
                    "type": .string("string"),
                    "description": .string("One-line description used to determine relevance in future conversations. Be specific."),
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("Full memory content. For feedback/project types, structure as: rule/fact, then **Why:** and **How to apply:** lines"),
                ]),
                "scope": .object([
                    "type": .string("string"),
                    "enum": .array([.string("global"), .string("project")]),
                    "description": .string("Scope: global (cross-project) or project (current project only). user and feedback types typically use global, project and reference types typically use project"),
                ]),
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Required when scope=project. The absolute path to the current project."),
                ]),
            ]),
            "required": .array([.string("id"), .string("type"), .string("name"), .string("description"), .string("content")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "保存记忆"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let id = MemoryToolInput.string(arguments["id"]?.anyValue) else {
            throw MemoryToolError.missingArgument("id")
        }
        guard let typeRaw = MemoryToolInput.string(arguments["type"]?.anyValue), let type = MemoryType(rawValue: typeRaw) else {
            throw MemoryToolError.invalidArgument("type must be one of: user, feedback, project, reference")
        }
        guard let name = MemoryToolInput.string(arguments["name"]?.anyValue) else {
            throw MemoryToolError.missingArgument("name")
        }
        guard let description = MemoryToolInput.string(arguments["description"]?.anyValue) else {
            throw MemoryToolError.missingArgument("description")
        }
        guard let content = MemoryToolInput.string(arguments["content"]?.anyValue) else {
            throw MemoryToolError.missingArgument("content")
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
