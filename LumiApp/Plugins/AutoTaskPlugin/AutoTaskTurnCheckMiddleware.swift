import Foundation
import LumiCoreKit
import os
import PluginAutoTask

/// AutoTask Turn 结束检查中间件
///
/// 在一个 Agent Turn 正常结束后，检查当前对话是否存在未完成的任务
///（`in_progress` 或 `pending`）。如果有，则向消息队列中入队一条提示消息，
/// 触发新的 Turn 让大模型检查并继续推进任务。
///
/// ## 触发条件
/// - Turn 正常完成（非取消、非错误、非用户拒绝）
/// - 存在 `in_progress` 或 `pending` 状态的任务
/// - 本轮消息中没有 `update_task` 工具调用（避免无限循环）
///
/// ## 无限循环防护
/// - 仅在 `endReason == .completed` 时触发
/// - 检查本轮是否已调用过 `update_task`，如果有则不再触发
/// - 入队的是 user 消息，走正常的消息队列流程
@MainActor
struct AutoTaskTurnCheckMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true

    let id = "auto_task_turn_check"
    let order: Int = 200 // 在其他中间件之后执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 此中间件不干预发送流程
        await next(ctx)
    }

    func handleTurnFinished(ctx: TurnFinishedContext) async {
        // 仅在正常完成时检查
        guard ctx.endReason == .completed else { return }

        // 获取 App 层上下文
        guard let appCtx = ctx as? AppTurnFinishedContext else { return }

        let conversationId = ctx.conversationId
        let conversationIdStr = conversationId.uuidString
        let manager = TaskStateManager.shared

        // 获取所有未完成的任务（in_progress + pending）
        let tasks = await manager.fetchTasks(conversationId: conversationIdStr)
        let activeTasks = tasks.filter { $0.status == .inProgress || $0.status == .pending }

        // 没有活跃任务，无需提示
        guard !activeTasks.isEmpty else { return }

        // 检查本轮是否调用了 update_task（避免无限循环）
        let hasUpdateCall = ctx.turnMessages.contains { message in
            guard message.role == .assistant, let toolCalls = message.toolCalls else { return false }
            return toolCalls.contains { $0.name == "update_task" }
        }

        // 本轮已调用过 update_task，说明大模型已在处理任务，无需重复提示
        guard !hasUpdateCall else {
            if Self.verbose {
                AutoTaskPlugin.logger.info("\(Self.t)本轮已调用 update_task，跳过任务检查提示")
            }
            return
        }

        // 构建提示消息
        let prompt = buildTaskCheckPrompt(tasks: activeTasks)

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)检测到 \(activeTasks.count) 个未完成任务（in_progress + pending），入队检查提示")
        }

        // 创建 user 消息并入队，触发新的 Turn
        let message = ChatMessage(
            role: .user,
            conversationId: conversationId,
            content: prompt
        )
        appCtx.messageQueueVM.enqueueMessage(message)
    }

    // MARK: - Private

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
