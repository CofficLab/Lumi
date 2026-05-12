import Foundation
import MagicKit

/// AutoTask 进度注入中间件
///
/// 在每轮对话中自动注入当前任务进度，保持 Agent 的全局视野。
/// 注入内容包括：当前进行中的任务、下一个待办任务、整体进度。
///
/// - Order: 70（位于 ToolCallLoopDetection(100) 之前、较早注入）
/// - 仅当该会话存在任务时才注入，无任务时不干扰正常对话
@MainActor
struct TaskContextMiddleware: SuperSendMiddleware, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false

    let id = "auto_task_context"
    let order: Int = 70

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        let conversationId = ctx.conversationId.uuidString
        let manager = TaskStateManager.shared

        let tasks = await manager.fetchTasks(conversationId: conversationId)
        let summary = await manager.getProgressSummary(conversationId: conversationId)

        // 无任务时不注入
        guard !summary.isEmpty else {
            await next(ctx)
            return
        }

        let prompt = buildProgressPrompt(tasks: tasks, summary: summary)
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)注入任务进度：\(summary.completed)/\(summary.total) (\(summary.completionPercent)%)")
        }

        await next(ctx)
    }

    // MARK: - Private

    /// 构建进度注入 Prompt
    private func buildProgressPrompt(tasks: [TaskItem], summary: TaskProgressSummary) -> String {
        var prompt = "## Project Task Progress\n"

        // 整体进度
        if summary.isAllDone {
            prompt += "**Status:** ✅ All \(summary.total) tasks completed!\n"
            prompt += "No further task action needed.\n"
            return prompt
        }

        prompt += "**Progress:** \(summary.completed + summary.skipped)/\(summary.total) tasks done (\(summary.completionPercent)%)\n\n"

        // 当前焦点（进行中的任务）
        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        if let current = inProgressTasks.first {
            prompt += "**Current Focus:** \(current.title)\n"
            if let detail = current.detail {
                prompt += "_\(detail)_\n"
            }
            prompt += "\n"
        }

        // 接下来的待办任务（最多显示 5 个）
        let pendingTasks = tasks.filter { $0.status == .pending }
        if !pendingTasks.isEmpty {
            prompt += "**Remaining:**\n"
            for task in pendingTasks.prefix(5) {
                prompt += "- \(task.title)\n"
            }
            if pendingTasks.count > 5 {
                prompt += "- ... and \(pendingTasks.count - 5) more\n"
            }
            prompt += "\n"
        }

        // 提醒指令
        prompt += "**Important:** Focus on completing the current task. "
        prompt += "When done, call `update_task` with status 'completed', then move to the next task.\n"

        return prompt
    }
}
