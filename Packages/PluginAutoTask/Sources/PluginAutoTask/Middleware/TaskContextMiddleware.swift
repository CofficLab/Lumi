import AgentToolKit
import Foundation
import SuperLogKit

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
    nonisolated static let verbose: Bool = true

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

        let prompt = buildProgressPrompt(
            tasks: tasks,
            summary: summary,
            languagePreference: ctx.projectVM.languagePreference
        )
        ctx.transientSystemPrompts.append(prompt)

        if Self.verbose {
            AutoTaskPlugin.logger.info("\(Self.t)注入任务进度：\(summary.completed)/\(summary.total) (\(summary.completionPercent)%)")
        }

        await next(ctx)
    }

    // MARK: - Private

    /// 构建进度注入 Prompt
    private func buildProgressPrompt(
        tasks: [TaskItem],
        summary: TaskProgressSummary,
        languagePreference: LanguagePreference
    ) -> String {
        switch languagePreference {
        case .chinese:
            return buildChineseProgressPrompt(tasks: tasks, summary: summary)
        case .english:
            return buildEnglishProgressPrompt(tasks: tasks, summary: summary)
        }
    }

    private func buildEnglishProgressPrompt(tasks: [TaskItem], summary: TaskProgressSummary) -> String {
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

        // 强提醒指令
        prompt += "---\n"
        prompt += "**⚠️ CRITICAL RULE:**\n"

        if let current = inProgressTasks.first {
            prompt += "- Task **\"\(current.title)\"** (`\(current.id)`) is currently **in_progress**.\n"
            prompt += "- When you finish this task, you MUST immediately call `update_task(task_id: \"\(current.id)\", status: \"completed\")` before doing anything else.\n"
            prompt += "- Do NOT start the next task without calling `update_task` first.\n"
        } else if !pendingTasks.isEmpty {
            let next = pendingTasks.first!
            prompt += "- Call `update_task(task_id: \"\(next.id)\", status: \"in_progress\")` to start the next task: **\(next.title)**\n"
        }

        prompt += "---\n"

        return prompt
    }

    private func buildChineseProgressPrompt(tasks: [TaskItem], summary: TaskProgressSummary) -> String {
        var prompt = "## 项目任务进度\n"

        if summary.isAllDone {
            prompt += "**状态：** ✅ 全部 \(summary.total) 个任务已完成！\n"
            prompt += "无需继续执行任务动作。\n"
            return prompt
        }

        prompt += "**进度：** \(summary.completed + summary.skipped)/\(summary.total) 个任务已完成（\(summary.completionPercent)%）\n\n"

        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        if let current = inProgressTasks.first {
            prompt += "**当前焦点：** \(current.title)\n"
            if let detail = current.detail {
                prompt += "_\(detail)_\n"
            }
            prompt += "\n"
        }

        let pendingTasks = tasks.filter { $0.status == .pending }
        if !pendingTasks.isEmpty {
            prompt += "**剩余任务：**\n"
            for task in pendingTasks.prefix(5) {
                prompt += "- \(task.title)\n"
            }
            if pendingTasks.count > 5 {
                prompt += "- ... 以及另外 \(pendingTasks.count - 5) 个\n"
            }
            prompt += "\n"
        }

        prompt += "---\n"
        prompt += "**⚠️ 关键规则：**\n"

        if let current = inProgressTasks.first {
            prompt += "- 任务 **\"\(current.title)\"** (`\(current.id)`) 当前处于 **in_progress** 状态。\n"
            prompt += "- 完成该任务后，必须先调用 `update_task(task_id: \"\(current.id)\", status: \"completed\")`，然后才能做其他事。\n"
            prompt += "- 调用 `update_task` 前，不要开始下一个任务。\n"
        } else if !pendingTasks.isEmpty {
            let next = pendingTasks.first!
            prompt += "- 调用 `update_task(task_id: \"\(next.id)\", status: \"in_progress\")` 开始下一个任务：**\(next.title)**\n"
        }

        prompt += "---\n"

        return prompt
    }
}
