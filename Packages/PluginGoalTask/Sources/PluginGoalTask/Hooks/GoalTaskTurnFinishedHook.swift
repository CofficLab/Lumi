import Foundation
import LumiLoggingKit
import os
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage

/// `turnFinished` 钩子：回合完成后推进 GoalTask 自动续跑。
@MainActor
final class GoalTaskTurnFinishedHook {
    private let agentLoop: any AgentLoopProviding
    private let messages: any MessageManaging

    init(agentLoop: any AgentLoopProviding, messages: any MessageManaging) {
        self.agentLoop = agentLoop
        self.messages = messages
    }

    func apply(to context: TurnLifecycleContext) async {
        switch context.endReason {
        case .completed:
            await GoalTaskContinuation.handle(
                conversationID: context.conversationID,
                turnID: context.turnID,
                agentLoop: agentLoop,
                messages: messages
            )
        case .suspended:
            // goal 活跃期模型仍可能调用 ask_user 提问。该调用会把回合挂起并
            // 打断自动续跑，因此在这里代答并恢复，让模型按默认假设继续走。
            await GoalTaskSuspensionRecovery.handle(
                conversationID: context.conversationID,
                agentLoop: agentLoop
            )
        case .failed, .cancelled:
            break
        case .none:
            break
        }
    }
}

/// 回合完成后检查未完成目标，达到自动续跑条件时触发下一轮。
private enum GoalTaskContinuation {
    @MainActor
    static func handle(
        conversationID: UUID,
        turnID: UUID,
        agentLoop: any AgentLoopProviding,
        messages: any MessageManaging
    ) async {
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
        guard let attempt = await manager.incrementContinuationCount(conversationId: conversationId) else {
            messages.insertMessage(
                GoalTaskTimeline.limitReachedMessage(
                    conversationID: conversationID,
                    turnID: turnID,
                    maxAttempts: GoalStateManager.maxAutomaticContinuations,
                    goalTitles: activeGoals.map(\.title)
                ),
                to: conversationID
            )
            for goal in goals where goal.status != .completed && goal.status != .skipped {
                _ = try? await manager.updateGoalStatus(
                    id: goal.id, status: .failed,
                    failureReason: "Automatic continuation limit reached before all tasks were completed."
                )
            }
            postChange(conversationId)
            return
        }
        messages.insertMessage(
            GoalTaskTimeline.continuationMessage(
                conversationID: conversationID,
                turnID: turnID,
                attempt: attempt,
                maxAttempts: GoalStateManager.maxAutomaticContinuations,
                goalTitles: activeGoals.map(\.title)
            ),
            to: conversationID
        )
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

/// goal 活跃期的 `ask_user` 自动代答。
///
/// `ask_user` 是当前唯一会把回合变成 `.suspended` 的常规路径，而自动续跑
/// 只在 `.completed` 上生效 —— 模型一旦提问，整个 goal 就停在那里等用户。
/// 这里按最小假设代替用户作答并恢复回合，让模型带着「已做决定」的上下文
/// 继续推进，把需要用户拍板的内容留到最后一起汇报。
///
/// 识别挂起点不 import `PluginAskUser`：payload 是该插件自己编码的 JSON，
/// 其中 `toolCallId` 恒为 `"ask_user"`，据此即可与授权等待等其它挂起区分。
private enum GoalTaskSuspensionRecovery: SuperLog {
    nonisolated static let emoji = "🔓"
    nonisolated static let verbose = false

    @MainActor
    static func handle(
        conversationID: UUID,
        agentLoop: any AgentLoopProviding
    ) async {
        guard let manager = Plugin.currentManager() else { return }
        let conversationId = conversationID.uuidString

        let goals = await manager.fetchGoals(conversationId: conversationId)
        let hasActiveGoal = goals.contains { $0.status == .pending || $0.status == .inProgress }
        guard hasActiveGoal else { return }

        guard let suspension = agentLoop.suspension(for: conversationID),
              Self.isAskUserSuspension(suspension) else { return }

        // 预算用于兜住「模型反复问同一个问题」的空转；耗尽后交回用户。
        guard await manager.incrementAskUserAnswerCount(conversationId: conversationId) != nil else {
            return
        }

        // 让 `willSendToLLM` 钩子知道恢复后的那一轮同样属于续跑，
        // 从而注入「直接接下一个任务」的指令而不是重新汇报。
        await manager.markContinuation(conversationId: conversationId)

        Task { @MainActor in
            await Task.yield()
            do {
                _ = try await agentLoop.resumeTurn(
                    in: conversationID,
                    request: AgentTurnResumeRequest(
                        suspensionID: suspension.suspensionID,
                        answer: Self.autonomousAnswer
                    )
                )
            } catch {
                Self.logger.error("\(Self.t)goal 活跃期自动代答 ask_user 失败：\(error.localizedDescription)")
            }
        }
    }

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.goal-task.suspension"
    )

    /// 挂起点是否来自 `ask_user`。
    ///
    /// 授权等待与 ask_user 共用 `kind == "userInput"` 与 `userInput:` 前缀的
    /// suspensionID，只能靠 payload 内容区分：ask_user 的 payload 是它自己
    /// 编码的 JSON，且 `toolCallId` 恒为 `"ask_user"`。
    private static func isAskUserSuspension(_ suspension: AgentLoopSuspension) -> Bool {
        guard suspension.suspensionID.hasPrefix("userInput:") else { return false }
        guard let data = suspension.payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["toolCallId"] as? String == "ask_user" else {
            return false
        }
        // 参数校验失败的 ask_user 也会被标成 awaitingUserResponse，但其结果以
        // 错误前缀开头，不构成一个真正的提问，不应代答。
        return (object["question"] as? String)?.isEmpty == false
    }

    /// 代答内容：让模型自行拍板并继续，而不是反复确认。
    private static let autonomousAnswer = """
    The user did not answer this question. An active goal is in progress, so do not ask again and do not stop.

    Decide the most reasonable option yourself, state the assumption you made, and continue executing the remaining tasks. Collect every question that genuinely needs a human decision and report them together in your final summary.
    """
}
