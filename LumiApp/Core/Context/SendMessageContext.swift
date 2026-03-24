import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage
    let chatHistoryService: ChatHistoryService
    let conversationVM: ConversationVM
    let agentSessionConfig: AgentSessionConfig

    init(
        conversationId: UUID,
        message: ChatMessage,
        chatHistoryService: ChatHistoryService,
        conversationVM: ConversationVM,
        agentSessionConfig: AgentSessionConfig
    ) {
        self.conversationId = conversationId
        self.message = message
        self.chatHistoryService = chatHistoryService
        self.conversationVM = conversationVM
        self.agentSessionConfig = agentSessionConfig
    }
}