import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage
    let chatHistoryService: ChatHistoryService
    let agentSessionConfig: LLMVM
    let projectVM: ProjectVM
    
    /// 仅在当前发送轮次有效的 system 提示词（不落库）
    ///
    /// 中间件可以将临时提示词添加到此数组，供 LLM 请求时使用。
    var transientSystemPrompts: [String] = []

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
            await chatHistoryService.saveMessage(systemMessage, toConversationId: conversationId)
        }
        abortTurn?()
    }
}
