import Foundation
import LumiChatKit
import LumiCoreKit
import os

/// 对话恢复服务
///
/// 负责执行对话恢复、忽略中断等业务操作，保持与主线程无关的状态变更入口。
public actor ConversationRecoveryService: Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-recovery.service")

    public static let shared = ConversationRecoveryService()

    private let monitor = ConversationRecoveryStateMonitor.shared

    private init() {}

    public func recover(interruption: LumiConversationInterruption) async {
        nonisolated logInfo("recover kind: \(interruption.kind)")

        switch interruption.kind {
        case .streamingInterrupted, .errorState, .turnNotCompleted:
            if let lastUserMessageID = interruption.lastUserMessageID,
               let chatService = ChatService.shared {
                await chatService.resendMessage(id: lastUserMessageID, in: interruption.conversationID)
            }

        case .toolExecutionIncomplete:
            if let chatService = ChatService.shared,
               let incompleteToolCallMessageID = interruption.incompleteToolCallMessageID {
                clearIncompleteToolCalls(
                    assistantMessageID: incompleteToolCallMessageID,
                    conversationID: interruption.conversationID,
                    chatService: chatService
                )
                chatService.continueTurn(in: interruption.conversationID)
            }

        case .awaitingUserResponse:
            break
        }

        monitor.markRecovered(conversationID: interruption.conversationID)
    }

    public func dismiss(interruption: LumiConversationInterruption) {
        nonisolated logInfo("dismiss kind: \(interruption.kind)")
        monitor.markRecovered(conversationID: interruption.conversationID)
    }

    // MARK: - Private

    private func clearIncompleteToolCalls(
        assistantMessageID: UUID,
        conversationID: UUID,
        chatService: ChatService
    ) {
        guard let message = chatService.messages(for: conversationID).first(where: { $0.id == assistantMessageID }),
              let toolCalls = message.toolCalls else {
            return
        }

        let incompleteToolCallIDs = toolCalls.filter { $0.result == nil }.map(\.id)

        for toolCallID in incompleteToolCallIDs {
            let errorResult = LumiToolResult(
                content: "工具执行被中断（App 崩溃或用户手动停止）。",
                isError: true
            )
            chatService.updateToolCallResult(
                errorResult,
                toolCallID: toolCallID,
                assistantMessageID: assistantMessageID,
                conversationID: conversationID
            )
        }
    }

    private nonisolated func logInfo(_ message: String) {
        Self.logger.info("\(message, privacy: .public)")
    }
}
