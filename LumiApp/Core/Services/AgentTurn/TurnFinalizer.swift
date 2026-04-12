import Foundation
import MagicKit

/// 回合收尾工具
///
/// 封装错误消息落库等样板代码，避免在主流程中散落。
@MainActor
final class TurnFinalizer: SuperLog {
    nonisolated static let emoji = "🏁"

    private let conversationVM: ConversationVM
    private let conversationSendStatusVM: ConversationStatusVM
    private let messageQueueVM: MessageQueueVM

    init(
        conversationVM: ConversationVM,
        conversationSendStatusVM: ConversationStatusVM,
        messageQueueVM: MessageQueueVM
    ) {
        self.conversationVM = conversationVM
        self.conversationSendStatusVM = conversationSendStatusVM
        self.messageQueueVM = messageQueueVM
    }

    /// 正常结束一轮对话。
    func finishTurn(conversationId: UUID, emitCompletionEvent: Bool = true) {
        messageQueueVM.finishProcessing(for: conversationId)
        conversationSendStatusVM.clearStatus(conversationId: conversationId)
        if emitCompletionEvent {
            NotificationCenter.postAgentConversationSendTurnFinished(conversationId: conversationId)
        }
    }

    /// 因错误结束一轮对话：保存错误消息并结束。
    func finishTurnWithError(
        _ error: Error,
        conversationId: UUID,
        providerId: String?
    ) {
        AppLogger.core.error("\(Self.t) 回合因错误终止：\(error.localizedDescription)")

        let errorMessage: ChatMessage
        if let llmError = error as? LLMServiceError {
            errorMessage = llmError.toChatMessage(conversationId: conversationId, providerId: providerId)
        } else {
            errorMessage = ChatMessage(
                role: .assistant,
                conversationId: conversationId,
                content: error.localizedDescription,
                isError: true
            )
        }

        conversationVM.saveMessage(errorMessage, to: conversationId)
        finishTurn(conversationId: conversationId)
    }

    /// 因取消结束一轮对话。
    func finishTurnByCancellation(conversationId: UUID) {
        conversationSendStatusVM.setStatus(conversationId: conversationId, content: "已停止生成")
        finishTurn(conversationId: conversationId, emitCompletionEvent: false)
    }

    /// 因用户拒绝工具执行结束一轮对话。
    func finishTurnByUserRejection(conversationId: UUID) {
        conversationSendStatusVM.setStatus(
            conversationId: conversationId,
            content: "用户拒绝执行工具，已结束回合"
        )
        finishTurn(conversationId: conversationId)
    }
}
