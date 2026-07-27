import Foundation
import LumiKernel

/// 提示词服务：负责生成 Goal/Task 相关的各种提示词
public final class PromptService: @unchecked Sendable {
    public init() {}
    
    // MARK: - Public APIs
    
    /// 生成 Goal 进度提示词（注入到 system prompt 中）
    public func buildGoalProgressPrompt(
        goal: Goal,
        tasks: [GoalTask],
        language: LumiConversationLanguage
    ) -> String {
        switch language {
        case .english:
            return buildEnglishGoalProgressPrompt(goal: goal, tasks: tasks)
        case .chinese:
            return buildChineseGoalProgressPrompt(goal: goal, tasks: tasks)
        }
    }
    
    /// 生成无 Goals 时的提示词（告诉 LLM 可以创建）
    public func buildNoGoalsPrompt(language: LumiConversationLanguage) -> String {
        switch language {
        case .english:
            return """
            ## 🎯 Goal Tracking Available

            No active goals in this conversation. Consider using `create_goal` when the user's request is complex.

            **Create a goal when:**
            - Refactoring across 3+ files
            - Implementing a feature with multiple sub-tasks
            - Debugging a multi-step issue
            - Any work likely spanning multiple turns

            **Skip goal when:**
            - Single-file simple edits
            - Answering questions / explaining code
            - User just asking "how to" do something

            **Available tools:** `create_goal`, `update_task_status`, `add_tasks_to_goal`, `update_goal_status`, `get_goal_progress`
            """
        case .chinese:
            return """
            ## 🎯 目标追踪可用

            当前对话没有进行中的目标。当用户的请求较复杂时，考虑使用 `create_goal`。

            **适合创建目标：**
            - 跨 3 个以上文件的重构
            - 实现包含多个子任务的功能
            - 需要多步排查的 bug 修复
            - 可能需要多轮对话才能完成的工作

            **不需要目标：**
            - 单文件的简单修改
            - 回答问题 / 解释代码
            - 用户只是在问"怎么做"

            **可用工具：** `create_goal`、`update_task_status`、`add_tasks_to_goal`、`update_goal_status`、`get_goal_progress`
            """
        }
    }
    
    /// 生成所有 Goals 已完成时的提示词
    public func buildGoalsCompletedPrompt(completedCount: Int, language: LumiConversationLanguage) -> String {
        switch language {
        case .english:
            return """
            ## 🎯 All Goals Completed

            All \(completedCount) goal(s) in this conversation have been completed. If the user has a new complex request, continue using `create_goal` as needed.

            **Available tools:** `create_goal`, `update_task_status`, `add_tasks_to_goal`, `update_goal_status`, `get_goal_progress`
            """
        case .chinese:
            return """
            ## 🎯 所有目标已完成

            本轮对话的 \(completedCount) 个目标已全部完成。如果用户有新的复杂请求，继续使用 `create_goal` 即可。

            **可用工具：** `create_goal`、`update_task_status`、`add_tasks_to_goal`、`update_goal_status`、`get_goal_progress`
            """
        }
    }
    
    // MARK: - English Prompts
    
    private func buildEnglishGoalProgressPrompt(goal: Goal, tasks: [GoalTask]) -> String {
        var prompt = "## 🎯 Current Goal\n"
        prompt += "**Title:** \(goal.title)\n"
        
        if let description = goal.goalDescription {
            prompt += "**Description:** \(description)\n"
        }
        
        if let successCriteria = goal.successCriteria {
            prompt += "**Success Criteria:** \(successCriteria)\n"
        }
        
        prompt += "\n"
        
        // 阻塞状态
        if goal.status == .blocked {
            prompt += "**⚠️ STATUS: BLOCKED**\n"
            if let reason = goal.blockedReason {
                prompt += "**Reason:** \(reason)\n"
            }
            prompt += "\nYou must NOT continue executing tasks. Wait for user input on how to proceed.\n\n"
            return prompt
        }
        
        // 失败状态
        if goal.status == .failed {
            prompt += "**❌ STATUS: FAILED**\n"
            if let reason = goal.failureReason {
                prompt += "**Reason:** \(reason)\n"
            }
            prompt += "\nThis goal cannot be achieved. Inform the user.\n\n"
            return prompt
        }
        
        // 任务列表
        let total = tasks.count
        let completed = tasks.filter { $0.status == .completed }.count
        let skipped = tasks.filter { $0.status == .skipped }.count
        let failed = tasks.filter { $0.status == .failed }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        
        prompt += "**Progress:** \(completed + skipped)/\(total) tasks done"
        if failed > 0 {
            prompt += " (\(failed) failed)"
        }
        prompt += "\n\n"
        
        // 当前焦点
        let currentTask = tasks.first { $0.status == .inProgress }
        if let current = currentTask {
            prompt += "**Current Focus:** \(current.title)\n"
            if let desc = current.taskDescription {
                prompt += "_\(desc)_\n"
            }
            if let context = current.executionContext {
                prompt += "_Context: \(context)_\n"
            }
            prompt += "\n"
        }
        
        // 剩余任务
        let pendingTasks = tasks.filter { $0.status == .pending }
        if !pendingTasks.isEmpty {
            prompt += "**Remaining Tasks:**\n"
            for task in pendingTasks.prefix(10) {
                let parallelMark = task.parallelGroup != nil ? " [parallel: \(task.parallelGroup!)]" : ""
                prompt += "- \(task.title)\(parallelMark)\n"
            }
            if pendingTasks.count > 10 {
                prompt += "- ... and \(pendingTasks.count - 10) more\n"
            }
            prompt += "\n"
        }
        
        prompt += "---\n"
        prompt += "**⚠️ CRITICAL RULES:**\n"
        
        if let current = currentTask {
            prompt += "- Task **\"\(current.title)\"** (`\(current.id)`) is currently **in_progress**.\n"
            prompt += "- When done, immediately call `update_task_status(task_id: \"\(current.id)\", status: \"completed\")`.\n"
            prompt += "- If you encounter a blocker, call `update_goal_status(goal_id: \"\(goal.id)\", status: \"blocked\", reason: \"...\")` and wait for user input.\n"
        } else if let next = pendingTasks.first {
            // 检查并行组
            let sameGroup = pendingTasks.filter { $0.parallelGroup == next.parallelGroup }
            if sameGroup.count > 1 {
                prompt += "- **Parallel Group \(next.parallelGroup ?? "default"):** You can execute these \(sameGroup.count) tasks concurrently:\n"
                for task in sameGroup {
                    prompt += "  - [\(task.id)] \(task.title)\n"
                }
                prompt += "- Update each task's status independently as you complete them.\n"
            } else {
                prompt += "- Next task: **\"\(next.title)\"** (`\(next.id)`)\n"
                prompt += "- Call `update_task_status(task_id: \"\(next.id)\", status: \"in_progress\")` to start, then `... \"completed\"` when done.\n"
            }
        }
        
        prompt += "---\n"
        return prompt
    }
    
    // MARK: - Chinese Prompts
    
    private func buildChineseGoalProgressPrompt(goal: Goal, tasks: [GoalTask]) -> String {
        var prompt = "## 🎯 当前目标\n"
        prompt += "**标题：** \(goal.title)\n"
        
        if let description = goal.goalDescription {
            prompt += "**描述：** \(description)\n"
        }
        
        if let successCriteria = goal.successCriteria {
            prompt += "**成功标准：** \(successCriteria)\n"
        }
        
        prompt += "\n"
        
        // 阻塞状态
        if goal.status == .blocked {
            prompt += "**⚠️ 状态：阻塞**\n"
            if let reason = goal.blockedReason {
                prompt += "**原因：** \(reason)\n"
            }
            prompt += "\n你不能继续执行任务。等待用户告知如何处理。\n\n"
            return prompt
        }
        
        // 失败状态
        if goal.status == .failed {
            prompt += "**❌ 状态：失败**\n"
            if let reason = goal.failureReason {
                prompt += "**原因：** \(reason)\n"
            }
            prompt += "\n此目标无法达成。请告知用户。\n\n"
            return prompt
        }
        
        // 任务列表
        let total = tasks.count
        let completed = tasks.filter { $0.status == .completed }.count
        let skipped = tasks.filter { $0.status == .skipped }.count
        let failed = tasks.filter { $0.status == .failed }.count
        
        prompt += "**进度：** \(completed + skipped)/\(total) 个任务已完成"
        if failed > 0 {
            prompt += "（\(failed) 个失败）"
        }
        prompt += "\n\n"
        
        // 当前焦点
        let currentTask = tasks.first { $0.status == .inProgress }
        if let current = currentTask {
            prompt += "**当前焦点：** \(current.title)\n"
            if let desc = current.taskDescription {
                prompt += "_\(desc)_\n"
            }
            if let context = current.executionContext {
                prompt += "_上下文：\(context)_\n"
            }
            prompt += "\n"
        }
        
        // 剩余任务
        let pendingTasks = tasks.filter { $0.status == .pending }
        if !pendingTasks.isEmpty {
            prompt += "**剩余任务：**\n"
            for task in pendingTasks.prefix(10) {
                let parallelMark = task.parallelGroup != nil ? " [并行：\(task.parallelGroup!)]" : ""
                prompt += "- \(task.title)\(parallelMark)\n"
            }
            if pendingTasks.count > 10 {
                prompt += "- ... 以及另外 \(pendingTasks.count - 10) 个\n"
            }
            prompt += "\n"
        }
        
        prompt += "---\n"
        prompt += "**⚠️ 关键规则：**\n"
        
        if let current = currentTask {
            prompt += "- 任务 **\"\(current.title)\"** (`\(current.id)`) 当前处于 **in_progress** 状态。\n"
            prompt += "- 完成后立即调用 `update_task_status(task_id: \"\(current.id)\", status: \"completed\")`。\n"
            prompt += "- 如果遇到阻塞，调用 `update_goal_status(goal_id: \"\(goal.id)\", status: \"blocked\", reason: \"...\")` 并等待用户输入。\n"
        } else if let next = pendingTasks.first {
            // 检查并行组
            let sameGroup = pendingTasks.filter { $0.parallelGroup == next.parallelGroup }
            if sameGroup.count > 1 {
                prompt += "- **并行组 \(next.parallelGroup ?? "default")：** 你可以并发执行这 \(sameGroup.count) 个任务：\n"
                for task in sameGroup {
                    prompt += "  - [\(task.id)] \(task.title)\n"
                }
                prompt += "- 独立更新每个任务的状态。\n"
            } else {
                prompt += "- 下一个任务：**\"\(next.title)\"** (`\(next.id)`)\n"
                prompt += "- 调用 `update_task_status(task_id: \"\(next.id)\", status: \"in_progress\")` 开始，完成后调用 `... \"completed\"`。\n"
            }
        }
        
        prompt += "---\n"
        return prompt
    }
}