import Foundation
import LumiKernel
import os

/// GoalTask 中间件：在每轮对话中注入当前 Goal 的进度信息
struct GoalContextMiddleware: LumiSendMiddleware {
    private let promptService: PromptService

    init(promptService: PromptService = PromptService()) {
        self.promptService = promptService
    }

    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let conversationId = context.conversationID.uuidString

        guard let manager = await GoalTaskPlugin.currentManager() else {
            // manager 尚未初始化：按"无 Goal"处理，注入创建提示
            updated.systemPromptFragments.append(
                promptService.buildNoGoalsPrompt(language: context.conversationLanguage)
            )
            return updated
        }

        // 获取当前会话的所有 Goals
        let goals = await manager.fetchGoals(conversationId: conversationId)
        
        if goals.isEmpty {
            // 没有 Goal 时，注入提示 LLM 可以创建
            updated.systemPromptFragments.append(
                promptService.buildNoGoalsPrompt(language: context.conversationLanguage)
            )
            return updated
        }
        
        // 检查是否处于续聊轮次
        let isContinuation = await manager.consumeContinuation(conversationId: conversationId)
        
        // 注入每个活跃 Goal 的进度
        var completedCount = 0
        var hasActiveGoal = false
        
        for goal in goals {
            if goal.status == .completed || goal.status == .skipped {
                completedCount += 1
                continue
            }
            
            hasActiveGoal = true
            
            let tasks = await manager.fetchTasks(goalId: goal.id)
            var goalPrompt = promptService.buildGoalProgressPrompt(
                goal: goal,
                tasks: tasks,
                language: context.conversationLanguage
            )
            
            // 如果是续聊轮次，添加更强的推进提示
            if isContinuation {
                let continuationHint = buildContinuationHint(language: context.conversationLanguage)
                goalPrompt += "\n\n" + continuationHint
            }
            
            updated.systemPromptFragments.append(goalPrompt)
        }
        
        // 所有 goals 都已完成/跳过时，注入完成提示
        if !hasActiveGoal && completedCount > 0 {
            updated.systemPromptFragments.append(
                promptService.buildGoalsCompletedPrompt(
                    completedCount: completedCount,
                    language: context.conversationLanguage
                )
            )
        }
        
        return updated
    }
    
    /// 生成续聊轮次的强推进提示
    private func buildContinuationHint(language: LumiConversationLanguage) -> String {
        switch language {
        case .english:
            return """
            ---
            **🔄 AUTO-CONTINUATION MODE:** This turn was automatically continued because there are still active tasks pending. 
            
            **You MUST immediately take action on the current task(s):**
            - If a task is in_progress, continue working on it right now
            - Call `update_task_status` to mark completion or report blockers
            - Do NOT wait for user input unless you encounter a blocker
            
            Continue executing the remaining tasks until all are completed or blocked.
            """
        case .chinese:
            return """
            ---
            **🔄 自动续聊模式：** 本轮是自动续聊，因为仍有活跃任务未完成。
            
            **你必须立即对当前任务采取行动：**
            - 如果有任务处于 in_progress 状态，立即继续执行
            - 调用 `update_task_status` 标记完成或报告阻塞
            - 除非遇到阻塞，否则不要等待用户输入
            
            继续执行剩余任务，直到全部完成或被阻塞。
            """
        }
    }
}