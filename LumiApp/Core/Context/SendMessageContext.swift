import Foundation
import MagicKit

@MainActor
final class SendMessageContext {
    let conversationId: UUID
    let message: ChatMessage

    init(conversationId: UUID, message: ChatMessage) {
        self.conversationId = conversationId
        self.message = message
    }
}