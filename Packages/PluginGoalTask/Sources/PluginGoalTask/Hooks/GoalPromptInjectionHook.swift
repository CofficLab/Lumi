import Foundation
import KitLLM
import ProviderLifecycleHooks
/// `willSendToLLM` 钩子：注入 Goal 自主执行契约与当前进度。
///
/// ## 为什么存在
///
/// Goal 建立之后，LLM 需要明确知道「自己要把计划走完，不要停下来问用户」。
/// 这条契约此前由旧版 `GoalContextMiddleware` + `PromptService` 注入，
/// 随旧 Middleware 体系一起被移除，导致 goal 契约在系统中完全缺位：
/// 唯一能让模型继续推进的机制只剩 `GoalTaskTurnFinishedHook` 的无感续跑，
/// 而模型在续跑轮看不到任何「继续走」的指令，只能反复总结并触发下一轮，
/// 直到耗尽 `maxAutomaticContinuations`。
///
/// ## 注入结构
///
/// 两条 system message 分离，静态在前、动态在后：
/// 1. `autonomyContract`：内容恒定，随活跃 goal 存在与否才增删。
///    放在最前可被 provider 的 prefix cache 命中。
/// 2. `goalProgress`：每轮随进度变化，不参与缓存。
///
/// 自动续跑轮额外追加一条「直接接下一个任务」的指令，避免模型把续跑
/// 当成一次重新汇报的开场。
///
/// 无活跃 goal 时原样返回，不产生任何 token 开销。
@MainActor
final class GoalPromptInjectionHook {
    func apply(to context: WillSendToLLMContext) async -> WillSendToLLMContext {
        guard let manager = Plugin.currentManager() else { return context }
        let conversationId = context.conversationID.uuidString

        let goals = await manager.fetchGoals(conversationId: conversationId)
        let activeGoals = goals.filter { Self.isActive($0) }

        // 没有任何可推进的目标时不注入。但被显式标记为 blocked 的 goal
        // 仍需告诉模型停下——那是人工介入的信号，不能沉默。
        guard !activeGoals.isEmpty else {
            guard let blocked = goals.first(where: { $0.status == .blocked }) else {
                return context
            }
            return Self.injecting(
                [Self.blockedPrompt(blocked)],
                into: context
            )
        }

        var injected = [Self.autonomyContract]

        for goal in activeGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            injected.append(Self.progressPrompt(goal: goal, tasks: tasks))
        }

        if await manager.consumeContinuation(conversationId: conversationId) {
            injected.append(Self.continuationPrompt)
        }

        return Self.injecting(injected, into: context)
    }

    // MARK: - Private Helpers

    /// 与 `GoalTaskTurnFinishedHook` 的活跃判定保持一致：
    /// 只有 pending / inProgress 会被自动续跑拾取，blocked 不在其中。
    private static func isActive(_ goal: Goal) -> Bool {
        goal.status == .pending || goal.status == .inProgress
    }

    private static func injecting(
        _ prompts: [String],
        into context: WillSendToLLMContext
    ) -> WillSendToLLMContext {
        var result = context
        result.messages = prompts.map { LLMMessage(role: .system, content: $0) } + context.messages
        return result
    }

    /// goal 被标记为 blocked 时唯一的合法动作是等待人工介入。
    /// 此时不应再叠加自主执行契约，否则两条指令会互相抵消。
    private static func blockedPrompt(_ goal: Goal) -> String {
        var prompt = "## 🎯 Goal Blocked\n"
        prompt += "**Title:** \(goal.title)\n"
        if let reason = goal.blockedReason {
            prompt += "**Reason:** \(reason)\n"
        }
        prompt += "\nSTATUS: BLOCKED\n"
        prompt += "Do NOT continue executing tasks. Do NOT start new work. "
        prompt += "Report the blocker to the user and wait for their input.\n"
        return prompt
    }

    /// 自动续跑轮的开场指令。
    ///
    /// 续跑消息本身带 `renderKind = "goal-task-continuation"`，会被
    /// `MessageTimelineEvent.isTimelineEvent` 从 LLM 上下文里过滤掉，
    /// 因此模型这一轮收到的上下文与「刚说完话」完全一致，需要显式
    /// 告知它这一轮的性质。
    private static let continuationPrompt = """
    ## ▶️ Automatic Continuation

    The previous turn ended without finishing the goal. This turn is an automatic continuation.

    - Do NOT summarize or recap what you already did.
    - Do NOT ask whether to continue, and do NOT ask any question.
    - Immediately resume from the first unfinished task listed above.
    """

    /// 静态自主执行契约。内容恒定，避免每轮变动破坏 prompt cache。
    private static let autonomyContract = """
    ## 🎯 Autonomous Execution Contract

    An active goal exists in this conversation. You own driving it to completion.

    **Never do these while a goal is active:**
    - Do NOT call `ask_user` or ask the user any question.
    - Do NOT end a turn with "want me to continue?", "shall I proceed?",
      "please confirm", or any other request for permission.
    - Do NOT pause for approval between tasks.

    **When you hit uncertainty, decide and continue:**
    - Pick the most reasonable default assumption, act on it, and keep going.
    - Record the assumptions you made in your final summary so the user can correct them.
    - Prefer finishing the whole plan over stopping to ask.

    **Status discipline:**
    - `blocked` is reserved for cases that truly cannot progress without the user,
      such as missing credentials or an external resource only the user can provide.
      Even then, first skip that one task and continue with the remaining tasks.
    - Call `update_task_status` as soon as a task finishes; never batch status updates
      at the end.
    """

    /// 单个 goal 的进度视图，含任务表与当前焦点。
    private static func progressPrompt(goal: Goal, tasks: [GoalTask]) -> String {
        var prompt = "## 🎯 Current Goal\n"
        prompt += "**Goal ID:** `\(goal.id)`\n"
        prompt += "**Title:** \(goal.title)\n"
        if let description = goal.goalDescription {
            prompt += "**Description:** \(description)\n"
        }
        if let criteria = goal.successCriteria {
            prompt += "**Success Criteria:** \(criteria)\n"
        }

        let completed = tasks.filter { $0.status == .completed }.count
        let skipped = tasks.filter { $0.status == .skipped }.count
        let failed = tasks.filter { $0.status == .failed }.count
        let inProgress = tasks.filter { $0.status == .inProgress }
        prompt += "\n**Progress:** \(completed + skipped)/\(tasks.count) tasks done"
        if failed > 0 {
            prompt += " (\(failed) failed)"
        }
        prompt += "\n"

        if let current = inProgress.first {
            prompt += "\n**Current Focus:** \(current.title) (`\(current.id)`)\n"
            if let description = current.taskDescription {
                prompt += "_\(description)_\n"
            }
            if let context = current.executionContext {
                prompt += "_Context: \(context)_\n"
            }
        }

        let pending = tasks.filter { $0.status == .pending }
        if !pending.isEmpty {
            prompt += "\n**Remaining Tasks:**\n"
            for task in pending.prefix(10) {
                var line = "- `\(task.id)` \(task.title)"
                if let group = task.parallelGroup {
                    line += " [parallel group: \(group)]"
                }
                prompt += line + "\n"
            }
            if pending.count > 10 {
                prompt += "- ... and \(pending.count - 10) more (use `get_goal_progress` for the full list)\n"
            }
        }

        prompt += "\n---\n"
        if let current = inProgress.first {
            prompt += "Task **\"\(current.title)\"** (`\(current.id)`) is **in_progress**. "
            prompt += "When it is done, immediately call "
            prompt += "`update_task_status(task_id: \"\(current.id)\", status: \"completed\")`, "
            prompt += "then move to the next unfinished task without stopping.\n"
        } else if let next = pending.first {
            let sameGroup = next.parallelGroup.map { group in
                pending.filter { $0.parallelGroup == group }
            } ?? []
            if sameGroup.count > 1 {
                prompt += "Parallel group **\(next.parallelGroup ?? "")** — these \(sameGroup.count) tasks can run concurrently:\n"
                for task in sameGroup {
                    prompt += "- `\(task.id)` \(task.title)\n"
                }
                prompt += "Update each one independently as it completes.\n"
            } else {
                prompt += "Next task: **\"\(next.title)\"** (`\(next.id)`). "
                prompt += "Call `update_task_status(task_id: \"\(next.id)\", status: \"in_progress\")` "
                prompt += "to start, then `... status: \"completed\"` when done.\n"
            }
        } else {
            prompt += "All tasks are finished. Verify against the success criteria, then call "
            prompt += "`update_goal_status(goal_id: \"\(goal.id)\", status: \"completed\")` "
            prompt += "or `skipped` for the ones you could not do.\n"
        }
        prompt += "---\n"
        return prompt
    }
}
