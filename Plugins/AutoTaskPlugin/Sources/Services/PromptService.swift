import Foundation
import LumiKernel

/// 提示词服务：负责生成任务相关的各种提示词
public final class PromptService: @unchecked Sendable {
    public init() {}

    // MARK: - Public APIs

    /// 生成进度提示词
    public func buildProgressPrompt(
        tasks: [TaskItem],
        summary: TaskProgressSummary,
        language: LumiConversationLanguage
    ) -> String {
        switch language {
        case .english:
            return buildEnglishProgressPrompt(tasks: tasks, summary: summary)
        case .chinese:
            return buildChineseProgressPrompt(tasks: tasks, summary: summary)
        }
    }

    /// 生成续聊提示词（用于无感自动续聊场景）
    public func buildContinuationPrompt(
        tasks: [TaskItem],
        language: LumiConversationLanguage
    ) -> String {
        switch language {
        case .english:
            return buildEnglishContinuationPrompt(tasks: tasks)
        case .chinese:
            return buildChineseContinuationPrompt(tasks: tasks)
        }
    }

    // MARK: - English Prompts

    private func buildEnglishContinuationPrompt(tasks: [TaskItem]) -> String {
        var prompt = "## ⏭️ Continue Pending Tasks\n"
        prompt += "The previous turn ended, but these tasks are still incomplete. Continue working on them now.\n\n"

        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        let pendingTasks = tasks.filter { $0.status == .pending }

        if !inProgressTasks.isEmpty {
            prompt += "**In progress (verify and complete):**\n"
            for task in inProgressTasks {
                prompt += "- [\(task.id)] \(task.title)\n"
            }
            prompt += "\n"
        }
        if !pendingTasks.isEmpty {
            prompt += "**Not started:**\n"
            for task in pendingTasks {
                prompt += "- [\(task.id)] \(task.title)\n"
            }
            prompt += "\n"
        }

        prompt += "---\n"
        prompt += "**User's perspective:** The user can see this task list in the sidebar with all pending/in-progress tasks displayed. They expect you to continue working on these tasks.\n"
        prompt += "- If a task is done, call `update_task(task_id: \"...\", status: \"completed\")` immediately.\n"
        prompt += "- If a task needs to begin, call `update_task(task_id: \"...\", status: \"in_progress\")`.\n"
        prompt += "- Otherwise, keep working on the current task — do not stop until progress is made.\n"
        return prompt
    }

    private func buildEnglishProgressPrompt(tasks: [TaskItem], summary: TaskProgressSummary) -> String {
        var prompt = "## Project Task Progress\n"

        if summary.isAllDone {
            prompt += "**Status:** ✅ All \(summary.total) tasks completed!\n"
            prompt += "No further task action needed.\n"
            return prompt
        }

        prompt += "**Progress:** \(summary.completed + summary.skipped)/\(summary.total) tasks done (\(summary.completionPercent)%)\n\n"

        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        if let current = inProgressTasks.first {
            prompt += "**Current Focus:** \(current.title)\n"
            if let detail = current.detail {
                prompt += "_\(detail)_\n"
            }
            prompt += "\n"
        }

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

        prompt += "---\n"
        prompt += "**⚠️ CRITICAL RULE:**\n"

        if let current = inProgressTasks.first {
            prompt += "- Task **\"\(current.title)\"** (`\(current.id)`) is currently **in_progress**.\n"
            prompt += "- When you finish this task, you MUST immediately call `update_task(task_id: \"\(current.id)\", status: \"completed\")` before doing anything else.\n"
            prompt += "- Do NOT start the next task without calling `update_task` first.\n"
        } else if let next = pendingTasks.first {
            prompt += "- Call `update_task(task_id: \"\(next.id)\", status: \"in_progress\")` to start the next task: **\(next.title)**\n"
        }

        prompt += "---\n"
        return prompt
    }

    // MARK: - Chinese Prompts

    private func buildChineseContinuationPrompt(tasks: [TaskItem]) -> String {
        var prompt = "## ⏭️ 继续推进未完成任务\n"
        prompt += "上一轮已结束，但以下任务尚未完成，请立即继续处理。\n\n"

        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        let pendingTasks = tasks.filter { $0.status == .pending }

        if !inProgressTasks.isEmpty {
            prompt += "**进行中（请检查并完成）：**\n"
            for task in inProgressTasks {
                prompt += "- [\(task.id)] \(task.title)\n"
            }
            prompt += "\n"
        }
        if !pendingTasks.isEmpty {
            prompt += "**尚未开始：**\n"
            for task in pendingTasks {
                prompt += "- [\(task.id)] \(task.title)\n"
            }
            prompt += "\n"
        }

        prompt += "---\n"
        prompt += "**用户视角：** 用户可以在侧边栏看到包含所有待处理/进行中任务的列表，他们期望你继续处理这些任务。\n"
        prompt += "- 若任务已完成，请立即调用 `update_task(task_id: \"...\", status: \"completed\")`。\n"
        prompt += "- 若任务需要开始，请调用 `update_task(task_id: \"...\", status: \"in_progress\")`。\n"
        prompt += "- 否则继续处理当前任务，在取得进展前不要停下。\n"
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
        } else if let next = pendingTasks.first {
            prompt += "- 调用 `update_task(task_id: \"\(next.id)\", status: \"in_progress\")` 开始下一个任务：**\(next.title)**\n"
        }

        prompt += "---\n"
        return prompt
    }
}
