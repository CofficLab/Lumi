import Foundation
import LumiCoreKit
import SuperLogKit

/// AutoTask Turn 结束检查中间件。
///
/// 在一个 Agent Turn 正常结束后，检查当前对话是否存在未完成的任务。
/// 如有需要，通过 `AutoTaskConfiguration.enqueueUserMessage` 让 App 侧入队一条提示消息。
@MainActor
struct AutoTaskTurnCheckMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true

    let id = "auto_task_turn_check"
    let order: Int = 200

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await next(ctx)
    }

    func handleTurnFinished(ctx: TurnFinishedContext) async {
        guard ctx.endReason == .completed else { return }

        let conversationId = ctx.conversationId
        let conversationIdStr = conversationId.uuidString
        let manager = TaskStateManager.shared

        let tasks = await manager.fetchTasks(conversationId: conversationIdStr)
        let activeTasks = tasks.filter { $0.status == .inProgress || $0.status == .pending }

        guard !activeTasks.isEmpty else { return }

        let hasUpdateCall = ctx.turnMessages.contains { message in
            guard message.role == .assistant, let toolCalls = message.toolCalls else { return false }
            return toolCalls.contains { $0.name == "update_task" }
        }

        guard !hasUpdateCall else {
            if Self.verbose {
                AutoTaskPlugin.logger.info("\(Self.t)本轮已调用 update_task，跳过任务检查提示")
            }
            return
        }

        let prompt = buildTaskCheckPrompt(tasks: activeTasks)

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)检测到 \(activeTasks.count) 个未完成任务（in_progress + pending），入队检查提示")
        }

        let message = ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: prompt
        )
        AutoTaskPlugin.configuration.enqueueUserMessage(message, turnContext: ctx)
    }

    private func buildTaskCheckPrompt(tasks: [TaskItem]) -> String {
        var lines: [String] = []

        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        let pendingTasks = tasks.filter { $0.status == .pending }

        if !inProgressTasks.isEmpty && !pendingTasks.isEmpty {
            lines.append("以下任务尚未完成，请继续推进：")
            lines.append("")
            lines.append("【进行中】")
            for task in inProgressTasks {
                lines.append("- [\(task.id)] \(task.title)")
            }
            lines.append("")
            lines.append("【待开始】")
            for task in pendingTasks {
                lines.append("- [\(task.id)] \(task.title)")
            }
        } else if !inProgressTasks.isEmpty {
            lines.append("以下任务仍处于进行中状态，请检查它们是否已经完成：")
            lines.append("")
            for task in inProgressTasks {
                lines.append("- [\(task.id)] \(task.title)")
                if let detail = task.detail {
                    lines.append("  详情：\(detail)")
                }
            }
        } else {
            lines.append("以下任务尚未开始，请开始处理：")
            lines.append("")
            for task in pendingTasks {
                lines.append("- [\(task.id)] \(task.title)")
                if let detail = task.detail {
                    lines.append("  详情：\(detail)")
                }
            }
        }

        lines.append("")
        lines.append("如果某个任务已经完成，请调用 `update_task` 将其状态更新为 `completed`。")
        lines.append("如果某个任务需要进行中，请调用 `update_task` 将其状态更新为 `in_progress`。")
        lines.append("如果某个任务仍在进行中，请继续处理。")
        return lines.joined(separator: "\n")
    }
}
