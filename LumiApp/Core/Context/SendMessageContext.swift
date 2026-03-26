import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage
    let chatHistoryService: ChatHistoryService
    let agentSessionConfig: LLMVM
    let projectVM: ProjectVM

    /// 终止本轮发送的回调
    ///
    /// 中间件可以调用此回调来立即终止本轮发送流程。
    /// 调用后，后续的中间件和 LLM 请求都不会执行。
    var abortTurn: (() -> Void)?

    init(
        conversationId: UUID,
        message: ChatMessage,
        chatHistoryService: ChatHistoryService,
        agentSessionConfig: LLMVM,
        projectVM: ProjectVM
    ) {
        self.conversationId = conversationId
        self.message = message
        self.chatHistoryService = chatHistoryService
        self.agentSessionConfig = agentSessionConfig
        self.projectVM = projectVM
    }

    /// 便捷方法：终止并发送系统消息
    func abort(withMessage systemMessage: ChatMessage) {
        Task {
            await chatHistoryService.saveMessageAsync(systemMessage, toConversationId: conversationId)
        }
        abortTurn?()
    }
}