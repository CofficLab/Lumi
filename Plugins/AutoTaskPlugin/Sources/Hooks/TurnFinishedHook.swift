import Foundation
import LumiCoreKit

/// Turn 结束后检查未完成任务，并在需要时无感地自动续聊。
@MainActor
enum TurnFinishedHook {
    /// 插件钩子入口：当 agent turn 结束时被内核调用
    static func handle(
        context: LumiPluginContext,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        // 仅响应成功完成的 turn
        guard reason == .completed else { return }

        guard let chatService = context.resolve(LumiChatServicing.self) else {
            return
        }

        await checkAndContinue(conversationID: conversationID, chatService: chatService)
    }

    private static func checkAndContinue(
        conversationID: UUID,
        chatService: any LumiChatServicing
    ) async {
        guard let manager = AutoTaskPlugin.manager else {
            return
        }

        let conversationIdStr = conversationID.uuidString
        let tasks = await manager.fetchTasks(conversationId: conversationIdStr)
        let activeTasks = tasks.filter { $0.status == .inProgress || $0.status == .pending }

        guard !activeTasks.isEmpty else {
            await cleanupCompletedTasks(manager: manager, conversationId: conversationIdStr)
            return
        }

        let messages = chatService.messages(for: conversationID)
        let turnMessages = TurnDerivation.turnMessagesSinceLastUser(in: messages)
        let didUpdateTaskThisTurn = TurnDerivation.assistantCalledTool(named: "update_task", in: turnMessages)

        if didUpdateTaskThisTurn {
            await manager.resetContinuationCount(conversationId: conversationIdStr)
            return
        }

        guard await manager.incrementContinuationCount(conversationId: conversationIdStr) != nil else {
            await cleanupStaleTasks(manager: manager, conversationId: conversationIdStr)
            return
        }

        await manager.markContinuation(conversationId: conversationIdStr)
        chatService.continueTurn(in: conversationID)
    }

    private static func cleanupCompletedTasks(manager: TaskStateManager, conversationId: String) async {
        await manager.deleteAllForConversation(conversationId)
        NotificationCenter.default.post(
            name: .taskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }

    private static func cleanupStaleTasks(manager: TaskStateManager, conversationId: String) async {
        await manager.deleteAllForConversation(conversationId)
        NotificationCenter.default.post(
            name: .taskDidChange,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
}
