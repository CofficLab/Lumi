import Foundation
import LumiKernel
import os

/// AskUser 回答后自动继续 AgentTurn 的钩子
///
/// 当用户通过 ask_user 工具回答问题后，此钩子会被触发，
/// 自动调用 ChatService.continueTurn() 来恢复 Agent 循环。
@MainActor
enum AskUserResumeHook {
    /// 插件钩子入口：当 agent turn 结束时被内核调用
    ///
    /// 此钩子会检测当前 turn 是否因为等待用户回答而暂停，
    /// 如果是，则自动恢复 Agent 循环。
    static func handle(
        lumiCore: any LumiCoreAccessing,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        // 仅在 turn 因等待用户响应而结束时处理
        guard reason == .awaitingUserResponse else { return }

        guard let chatService = lumiCore.resolveService((any LumiChatServicing).self) else {
            return
        }

        // 检查是否有待处理的 ask_user 工具调用
        let messages = chatService.messages(for: conversationID)
        guard hasPendingAskUserToolCall(in: messages) else {
            return
        }

        // 注意：实际上 resumeAfterAskUser 已经处理了 continueAgentTurn
        // 这个 Hook 主要用于日志记录和调试
        Self.logger.info("🔄 AskUser: Turn ended with awaitingUserResponse for conversation \(conversationID.uuidString.prefix(8))")
    }

    /// 检查消息列表中是否有待处理的 ask_user 工具调用
    private static func hasPendingAskUserToolCall(in messages: [LumiChatMessage]) -> Bool {
        for message in messages.reversed() {
            guard message.role == .assistant,
                  let toolCalls = message.toolCalls
            else {
                continue
            }

            for toolCall in toolCalls {
                if toolCall.name == "ask_user",
                   let result = toolCall.result,
                   LumiAskUserMarkers.isPendingResponse(result.content) {
                    return true
                }
            }
        }
        return false
    }

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.ask-user.hook")
}
