import Foundation
import ProviderAgentLoop
import ProviderLifecycleHooks

/// `turnFinished` 钩子：回合完成后推进 GoalTask 自动续跑。
@MainActor
final class GoalTaskTurnFinishedHook {
    private let agentLoop: any AgentLoopProviding

    init(agentLoop: any AgentLoopProviding) {
        self.agentLoop = agentLoop
    }

    func apply(to context: TurnLifecycleContext) async {
        guard context.endReason == .completed else { return }
        await GoalTaskContinuation.handle(conversationID: context.conversationID, agentLoop: agentLoop)
    }
}

/// 回合完成后检查未完成目标，达到自动续跑条件时触发下一轮。
private enum GoalTaskContinuation {
    @MainActor
    static func handle(conversationID: UUID, agentLoop: any AgentLoopProviding) async {
        guard let manager = Plugin.currentManager() else { return }
        let conversationId = conversationID.uuidString
        let goals = await manager.fetchGoals(conversationId: conversationId)
        let activeGoals = goals.filter { $0.status == .pending || $0.status == .inProgress }
        guard !activeGoals.isEmpty else {
            if !goals.isEmpty, goals.allSatisfy({ $0.status == .completed || $0.status == .skipped }) {
                try? await manager.deleteAllGoals(conversationId: conversationId)
                postChange(conversationId)
            }
            return
        }
        var hasActiveTasks = false
        for goal in activeGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            if tasks.contains(where: { $0.status == .inProgress || $0.status == .pending }) {
                hasActiveTasks = true
                break
            }
        }
        guard hasActiveTasks else { return }
        guard await manager.incrementContinuationCount(conversationId: conversationId) != nil else {
            for goal in goals where goal.status != .completed && goal.status != .skipped {
                _ = try? await manager.updateGoalStatus(
                    id: goal.id, status: .failed,
                    failureReason: "Automatic continuation limit reached before all tasks were completed."
                )
            }
            postChange(conversationId)
            return
        }
        await manager.markContinuation(conversationId: conversationId)
        // The completed hook runs while the previous runTurn is unwinding.
        // Yield once so the next no-message turn cannot be rejected as concurrent.
        Task { @MainActor in
            await Task.yield()
            _ = try? await agentLoop.runTurn(in: conversationID)
        }
    }

    @MainActor private static func postChange(_ conversationId: String) {
        guard let conversationID = UUID(uuidString: conversationId) else { return }
        GoalChangeCenter.shared.notify(conversationID: conversationID)
    }
}
