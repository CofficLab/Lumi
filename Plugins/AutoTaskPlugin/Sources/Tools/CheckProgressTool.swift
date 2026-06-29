import AgentToolKit
import Foundation
import SuperLogKit
import LumiCoreKit

/// 查询任务进度工具
///
/// 用于查看当前会话的任务列表和完成进度。
/// Agent 可以在需要时主动查询进度，以确认下一步应该做什么。
public struct CheckProgressTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = true

    public let name = "check_progress"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "检查当前对话的任务进度。返回所有任务及其状态和总体完成百分比。用于回顾已完成内容和下一步事项。"
        case .english:
            return """
    Check the current task progress for the conversation. Returns a list of all tasks with their \
    statuses and overall completion percentage. Use this to review what's been done and what's next.
    """
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:] as [String: Any],
            "required": [] as [String],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "查看任务进度" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationId.uuidString
        let manager = TaskStateManager.shared
        let tasks = await manager.fetchTasks(conversationId: conversationId)
        let summary = await manager.getProgressSummary(conversationId: conversationId)

        if summary.isEmpty {
            return LumiPluginLocalization.string("No tasks found for this conversation. Use create_task to plan your work.", bundle: .module)
        }

        let doneCount = summary.completed + summary.skipped
        let progressLabel = LumiPluginLocalization.string("Task Progress", bundle: .module)
        var result = "## \(progressLabel): \(doneCount)/\(summary.total) (\(summary.completionPercent)%)\n\n"

        let statusIcons: [TaskItem.TaskStatus: String] = [
            .pending: "⬜",
            .inProgress: "🔄",
            .completed: "✅",
            .skipped: "⏭️",
        ]

        for task in tasks {
            let icon = statusIcons[task.status] ?? "⬜"
            result += "\(icon) **#\(task.order)** `\(task.id)` \(task.title)"
            if let detail = task.detail {
                result += "\n   _\(detail)_"
            }
            result += "\n"
        }

        if summary.isAllDone {
            result += "\n🎉 **\(LumiPluginLocalization.string("All tasks completed!", bundle: .module))**"
        } else if summary.inProgress > 0 {
            let current = tasks.first { $0.status == .inProgress }
            if let current {
                let focusLabel = LumiPluginLocalization.string("Current focus", bundle: .module)
                result += "\n📌 **\(focusLabel): \(current.title)**"
            }
            let nextTask = tasks.first { $0.status == .pending }
            if let next = nextTask {
                let nextUpLabel = LumiPluginLocalization.string("Next up", bundle: .module)
                result += "\n⏭️ **\(nextUpLabel): \(next.title)**"
            }
        } else if summary.pending > 0 {
            let nextTask = tasks.first { $0.status == .pending }
            if let next = nextTask {
                let nextTaskLabel = LumiPluginLocalization.string("Next task — start by calling update_task with status 'in_progress'", bundle: .module)
                result += "\n⏭️ **\(nextTaskLabel): \(next.title)**"
            }
        }

        return result
    }
}
