import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage
    let chatHistoryService: ChatHistoryService

    init(conversationId: UUID, message: ChatMessage, chatHistoryService: ChatHistoryService) {
        self.conversationId = conversationId
        self.message = message
        self.chatHistoryService = chatHistoryService
    }
}