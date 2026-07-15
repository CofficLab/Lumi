import Foundation
import LumiCoreKit
import SuperLogKit

/// 查询任务进度工具
///
/// 用于查看当前会话的任务列表和完成进度。
/// Agent 可以在需要时主动查询进度，以确认下一步应该做什么。
public struct CheckProgressTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = true

    /// 由插件注入的状态管理器。
    ///
    /// 由 `AutoTaskPlugin` 在 `agentTools(context:)` 中创建 Tool 时注入，
    /// 保证 Tool 持有生命周期一致的单实例。
    public let manager: TaskStateManager

    public static let info = LumiAgentToolInfo(
        id: "check_progress",
        displayName: LumiPluginLocalization.string("Check Progress", bundle: .module),
        description: LumiPluginLocalization.string(
            "Check the current task progress for the conversation. Returns a list of all tasks with their statuses and overall completion percentage. Use this to review what's been done and what's next.",
            bundle: .module
        )
    )

    public init(manager: TaskStateManager) {
        self.manager = manager
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "查看任务进度" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        let conversationId = context.conversationID.uuidString
        let manager = self.manager
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
