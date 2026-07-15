import Foundation
import LumiCoreKit
import os

/// AutoTask 进度注入中间件：在每轮对话中注入当前任务进度。
struct TaskContextChatMiddleware: LumiSendMiddleware {
    private let manager: TaskStateManager
    private let promptService: PromptService

    init(manager: TaskStateManager, promptService: PromptService = PromptService()) {
        self.manager = manager
        self.promptService = promptService
    }

    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let conversationId = context.conversationID.uuidString

        let tasks = await manager.fetchTasks(conversationId: conversationId)
        let summary = await manager.getProgressSummary(conversationId: conversationId)
        let isContinuation = await manager.consumeContinuation(conversationId: conversationId)

        guard !summary.isEmpty else {
            return updated
        }

        updated.systemPromptFragments.append(
            promptService.buildProgressPrompt(
                tasks: tasks,
                summary: summary,
                language: context.conversationLanguage
            )
        )

        // 若本轮是一次无感自动续聊（任务尚未完成但上一轮已结束），
        // 追加更强的"立即继续推进"指令。该提示只进 system prompt，
        // 不会作为用户消息出现在消息列表或持久化历史中。
        if isContinuation {
            let activeTasks = tasks.filter { $0.status == .inProgress || $0.status == .pending }
            if !activeTasks.isEmpty {
                updated.systemPromptFragments.append(
                    promptService.buildContinuationPrompt(
                        tasks: activeTasks,
                        language: context.conversationLanguage
                    )
                )
            }
        }
        return updated
    }
}
