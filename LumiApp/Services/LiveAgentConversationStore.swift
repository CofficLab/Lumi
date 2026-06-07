import Foundation
import LumiCoreKit

/// 桥接 `AgentConversationStore` 协议与 SwiftData 持久化服务。
@MainActor
final class LiveAgentConversationStore: AgentConversationStore, Sendable {
    private let messageService: MessageService
    private let conversationService: ConversationService

    init(messageService: MessageService, conversationService: ConversationService) {
        self.messageService = messageService
        self.conversationService = conversationService
    }

    func loadMessages(for conversationId: UUID) -> [ChatMessage] {
        messageService.loadMessages(forConversationId: conversationId) ?? []
    }

    func saveMessage(_ message: ChatMessage, conversationId: UUID) {
        _ = messageService.saveMessage(message, toConversationId: conversationId)
    }

    func loadTurnPhase(for conversationId: UUID) -> AgentTurnPhase {
        conversationService.loadTurnPhase(forConversationId: conversationId)
    }

    func setTurnPhase(_ phase: AgentTurnPhase, conversationId: UUID) {
        conversationService.setTurnPhase(phase, forConversationId: conversationId)
    }
}
