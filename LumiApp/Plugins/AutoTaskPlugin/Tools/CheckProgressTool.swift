import Foundation
import MagicKit

/// 查询任务进度工具
///
/// 用于查看当前会话的任务列表和完成进度。
/// Agent 可以在需要时主动查询进度，以确认下一步应该做什么。
struct CheckProgressTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose: Bool = false

    let name = "check_progress"
    let description = """
    Check the current task progress for the conversation. Returns a list of all tasks with their \
    statuses and overall completion percentage. Use this to review what's been done and what's next.
    """

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "conversation_id": [
                    "type": "string",
                    "description": "The conversation ID (UUID string) to check progress for",
                ],
            ],
            "required": ["conversation_id"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let conversationId = arguments["conversation_id"]?.value as? String else {
            return "Error: conversation_id is required"
        }

        let manager = TaskStateManager.shared
        let tasks = await manager.fetchTasks(conversationId: conversationId)
        let summary = await manager.getProgressSummary(conversationId: conversationId)

        if summary.isEmpty {
            return "No tasks found for this conversation. Use create_task to plan your work."
        }

        var result = "## Task Progress: \(summary.completed + summary.skipped)/\(summary.total) (\(summary.completionPercent)%)\n\n"

        let statusIcons: [TaskItem.TaskStatus: String] = [
            .pending: "⬜",
            .inProgress: "🔄",
            .completed: "✅",
            .skipped: "⏭️",
        ]

        for task in tasks {
            let icon = statusIcons[task.status] ?? "⬜"
            result += "\(icon) **#\(task.order)** \(task.title)"
            if let detail = task.detail {
                result += "\n   _\(detail)_"
            }
            result += "\n"
        }

        if summary.isAllDone {
            result += "\n🎉 **All tasks completed!**"
        } else if summary.inProgress > 0 {
            let current = tasks.first { $0.status == .inProgress }
            if let current {
                result += "\n📌 **Current focus:** \(current.title)"
            }
            let nextTask = tasks.first { $0.status == .pending }
            if let next = nextTask {
                result += "\n⏭️ **Next up:** \(next.title)"
            }
        } else if summary.pending > 0 {
            let nextTask = tasks.first { $0.status == .pending }
            if let next = nextTask {
                result += "\n⏭️ **Next task:** \(next.title) — start by calling update_task with status 'in_progress'"
            }
        }

        return result
    }
}
