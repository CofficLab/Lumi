import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage
    let chatHistoryService: ChatHistoryService
    let agentSessionConfig: AgentSessionConfig

    init(
        conversationId: UUID,
        message: ChatMessage,
        chatHistoryService: ChatHistoryService,
        agentSessionConfig: AgentSessionConfig
    ) {
        self.conversationId = conversationId
        self.message = message
        self.chatHistoryService = chatHistoryService
        self.agentSessionConfig = agentSessionConfig
    }
}