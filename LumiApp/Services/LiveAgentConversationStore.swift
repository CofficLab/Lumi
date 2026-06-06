import Foundation
import LumiCoreKit

/// 桥接 `AgentConversationStore` 协议与 SwiftData 持久化服务。
@MainActor
final class LiveAgentConversationStore: AgentConversationStore, Sendable {
    private let chatHistoryService: ChatHistoryService
    private let conversationService: ConversationService

    init(chatHistoryService: ChatHistoryService, conversationService: ConversationService) {
        self.chatHistoryService = chatHistoryService
        self.conversationService = conversationService
    }

    func loadMessages(for conversationId: UUID) -> [ChatMessage] {
        chatHistoryService.loadMessages(forConversationId: conversationId) ?? []
    }

    func saveMessage(_ message: ChatMessage, conversationId: UUID) {
        _ = chatHistoryService.saveMessage(message, toConversationId: conversationId)
    }

    func loadTurnPhase(for conversationId: UUID) -> AgentTurnPhase {
        conversationService.loadTurnPhase(forConversationId: conversationId)
    }

    func setTurnPhase(_ phase: AgentTurnPhase, conversationId: UUID) {
        conversationService.setTurnPhase(phase, forConversationId: conversationId)
    }
}
