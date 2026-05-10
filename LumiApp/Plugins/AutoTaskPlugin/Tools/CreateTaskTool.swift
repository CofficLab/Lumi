import Foundation
import MagicKit

/// 创建任务工具
///
/// 用于创建单个任务或批量创建任务列表。
/// 当用户提出复杂目标时，Agent 调用此工具将目标拆解为可执行的子任务。
struct CreateTaskTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false

    let name = "create_task"
    let description = """
    Create tasks for a complex goal. When the user asks you to do something that requires multiple steps, \
    break it down into tasks using this tool. You can create a single task or a batch of tasks at once. \
    Each task should be a concrete, actionable step. Tasks are tracked in a kanban board and you will be \
    reminded of progress automatically. After creating tasks, start working on the first one immediately.
    """

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "conversation_id": [
                    "type": "string",
                    "description": "The conversation ID (UUID string) to associate tasks with",
                ],
                "tasks": [
                    "type": "array",
                    "description": "Array of tasks to create. Each task has a title and optional detail.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": [
                                "type": "string",
                                "description": "Short, actionable task title (e.g., 'Setup project structure')",
                            ],
                            "detail": [
                                "type": "string",
                                "description": "Optional detailed description of what this task involves",
                            ],
                        ],
                        "required": ["title"],
                    ],
                ],
            ],
            "required": ["conversation_id", "tasks"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let conversationId = arguments["conversation_id"]?.value as? String else {
            return "Error: conversation_id is required"
        }

        guard let tasksArray = arguments["tasks"]?.value as? [[String: Any]] else {
            return "Error: tasks array is required"
        }

        guard !tasksArray.isEmpty else {
            return "Error: tasks array must not be empty"
        }

        let items: [(title: String, detail: String?)] = tasksArray.compactMap { item in
            guard let title = item["title"] as? String, !title.isEmpty else { return nil }
            let detail = item["detail"] as? String
            return (title: title, detail: detail)
        }

        guard !items.isEmpty else {
            return "Error: no valid tasks found (each task needs a non-empty title)"
        }

        let manager = TaskStateManager.shared
        await manager.createTasks(conversationId: conversationId, items: items)

        let summary = await manager.getProgressSummary(conversationId: conversationId)

        var result = "✅ Created \(items.count) tasks:\n\n"
        for (index, item) in items.enumerated() {
            result += "\(index + 1). **\(item.title)**"
            if let detail = item.detail {
                result += "\n   \(detail)"
            }
            result += "\n"
        }
        result += "\nNow start working on task #1: **\(items[0].title)**"

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)Created \(items.count) tasks for conversation \(conversationId)")
        }

        return result
    }
}
