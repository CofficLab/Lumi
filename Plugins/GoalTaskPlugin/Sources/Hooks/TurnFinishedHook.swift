import Foundation
import LumiKernel

/// Turn 结束后检查未完成的目标和任务，并在需要时无感地自动续聊。
@MainActor
enum TurnFinishedHook {
    /// 插件钩子入口：当 agent turn 结束时被内核调用
    static func handle(
        lumiCore: LumiKernel,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        // 仅响应成功完成的 turn
        guard reason == .completed else { return }

        guard let chatService = lumiCore.resolveService((any LumiChatServicing).self) else {
            return
        }

        await checkAndContinue(conversationID: conversationID, chatService: chatService)
    }

    private static func checkAndContinue(
        conversationID: UUID,
        chatService: any LumiChatServicing
    ) async {
        guard let manager = GoalTaskPlugin.currentManager() else {
            return
        }

        let conversationIdStr = conversationID.uuidString

        // 获取当前会话的所有 Goals
        let goals = await manager.fetchGoals(conversationId: conversationIdStr)

        // 过滤出活跃的 Goals（非 completed、skipped）
        let activeGoals = goals.filter { goal in
            goal.status != .completed && goal.status != .skipped
        }

        guard !activeGoals.isEmpty else {
            // 所有目标都已完成或跳过，清理数据
            await cleanupCompletedGoals(manager: manager, conversationId: conversationIdStr)
            return
        }

        // 检查是否有活跃的任务
        var hasActiveTasks = false
        for goal in activeGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            let activeTasks = tasks.filter { task in
                task.status == .inProgress || task.status == .pending
            }
            if !activeTasks.isEmpty {
                hasActiveTasks = true
                break
            }
        }

        guard hasActiveTasks else {
            // 没有活跃任务，清理已完成的目标
            await cleanupCompletedGoals(manager: manager, conversationId: conversationIdStr)
            return
        }

        // 简化版本：不检测工具调用，直接递增续聊计数
        // 如果达到最大续聊次数，将目标标记为失败并保留现场
        guard await manager.incrementContinuationCount(conversationId: conversationIdStr) != nil else {
            await markStaleGoalsFailed(manager: manager, conversationId: conversationIdStr)
            return
        }

        // 标记为无感自动续聊
        await manager.markContinuation(conversationId: conversationIdStr)

        // 不写入任何用户消息，直接重启一轮 agent turn
        chatService.continueTurn(in: conversationID)
    }

    private static func cleanupCompletedGoals(manager: GoalStateManager, conversationId: String) async {
        try? await manager.deleteAllGoals(conversationId: conversationId)

        // 发送通知，更新 UI
        NotificationCenter.default.post(
            name: .goalDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }

    private static func markStaleGoalsFailed(manager: GoalStateManager, conversationId: String) async {
        let failureReason = "Automatic continuation limit reached before all tasks were completed."
        let goals = await manager.fetchGoals(conversationId: conversationId)

        for goal in goals where goal.status != .completed && goal.status != .skipped {
            _ = try? await manager.updateGoalStatus(
                id: goal.id,
                status: .failed,
                failureReason: failureReason
            )
        }

        // 发送通知，更新 UI
        NotificationCenter.default.post(
            name: .goalDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
}
