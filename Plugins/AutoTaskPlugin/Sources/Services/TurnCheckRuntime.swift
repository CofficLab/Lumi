import Foundation
import LumiCoreKit

/// Turn 结束后检查未完成任务，并在需要时无感地自动续聊。
///
/// 仅响应 `lumiTurnFinished` 且 `reason == .completed` 的事件；
/// 供应商故障等失败 Turn 由 `LumiChatKit` 标记为 `.failed`，不会触发自动续聊。
///
/// 与旧实现的区别：续聊不再以用户消息形式入队，而是调用
/// `LumiChatServicing.continueTurn(in:)`，在不写入任何用户消息的前提下重启一轮
/// agent turn——既不进入消息列表、也不污染持久化历史，对用户完全无感。
@MainActor
enum TurnCheckRuntime {
    private static var observer: NSObjectProtocol?

    static func start(chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?) {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: .lumiTurnFinished,
            object: nil,
            queue: .main
        ) { notification in
            guard let conversationID = notification.userInfo?[LumiMessageSavedNotification.conversationIDKey] as? UUID else {
                return
            }
            guard let reason = LumiTurnEndReason(notificationUserInfo: notification.userInfo),
                  reason.allowsAutomaticContinuation
            else {
                return
            }
            Task { @MainActor in
                await handleSuccessfulTurnCompleted(
                    conversationID: conversationID,
                    chatServiceProvider: chatServiceProvider
                )
            }
        }
    }

    private static func handleSuccessfulTurnCompleted(
        conversationID: UUID,
        chatServiceProvider: @MainActor () -> (any LumiChatServicing)?
    ) async {
        guard let chatService = chatServiceProvider() else {
            return
        }

        let manager = TaskStateManager.shared
        let conversationIdStr = conversationID.uuidString
        let tasks = await manager.fetchTasks(conversationId: conversationIdStr)
        let activeTasks = tasks.filter { $0.status == .inProgress || $0.status == .pending }

        guard !activeTasks.isEmpty else {
            // All tasks completed — clean up so sidebar returns to clean state.
            await manager.deleteAllForConversation(conversationIdStr)
            NotificationCenter.default.post(
                name: .taskDidChange,
                object: nil,
                userInfo: ["conversationId": conversationIdStr]
            )
            return
        }

        let messages = chatService.messages(for: conversationID)
        let turnMessages = LumiAgentTurnDerivation.turnMessagesSinceLastUser(in: messages)
        let didUpdateTaskThisTurn = LumiAgentTurnDerivation.assistantCalledTool(named: "update_task", in: turnMessages)

        // 本轮 Agent 主动调用了 `update_task`，说明它在正常推进任务：
        // 解除「连续空转」戒备，重新给足续聊预算，无需介入。
        if didUpdateTaskThisTurn {
            await manager.resetContinuationCount(conversationId: conversationIdStr)
            return
        }

        // 本轮未推进任务：递增连续自动续聊计数，超过上限则停止，
        // 避免 LLM 卡住时无限空转（此时应交还给用户）。
        guard await manager.incrementContinuationCount(conversationId: conversationIdStr) != nil else {
            // Max continuations reached — clean up stale tasks.
            await manager.deleteAllForConversation(conversationIdStr)
            NotificationCenter.default.post(
                name: .taskDidChange,
                object: nil,
                userInfo: ["conversationId": conversationIdStr]
            )
            return
        }

        // 标记本轮为无感自动续聊，让 TaskContextChatMiddleware 注入更强的
        // 「立即继续推进」system prompt；随后不写任何消息直接重启一轮。
        await manager.markContinuation(conversationId: conversationIdStr)
        chatService.continueTurn(in: conversationID)
    }
}
