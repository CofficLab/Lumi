import Foundation
import LumiCoreKit
import os

/// GoalTask 中间件：在每轮对话中注入当前 Goal 的进度信息
struct GoalContextMiddleware: LumiSendMiddleware {
    private let manager: GoalStateManager
    private let promptService: PromptService
    
    init(manager: GoalStateManager, promptService: PromptService = PromptService()) {
        self.manager = manager
        self.promptService = promptService
    }
    
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let conversationId = context.conversationID.uuidString
        
        // 获取当前会话的所有 Goals
        let goals = await manager.fetchGoals(conversationId: conversationId)
        
        if goals.isEmpty {
            // 没有 Goal 时，注入提示 LLM 可以创建
            updated.systemPromptFragments.append(
                promptService.buildNoGoalsPrompt(language: context.conversationLanguage)
            )
            return updated
        }
        
        // 注入每个活跃 Goal 的进度
        for goal in goals {
            // 跳过已完成的 Goal
            if goal.status == .completed || goal.status == .skipped {
                continue
            }
            
            let tasks = await manager.fetchTasks(goalId: goal.id)
            updated.systemPromptFragments.append(
                promptService.buildGoalProgressPrompt(
                    goal: goal,
                    tasks: tasks,
                    language: context.conversationLanguage
                )
            )
        }
        
        return updated
    }
}