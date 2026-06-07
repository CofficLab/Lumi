import Foundation
import LumiCoreKit

@MainActor
enum ConversationTitleRuntimeBridge {
    static var fetchConversationTitle: (UUID) -> String? = { _ in nil }
    static var updateConversationTitle: (UUID, String) -> Bool = { _, _ in false }
    static var loadMessages: (UUID) -> [ChatMessage] = { _ in [] }
    static var llmSendService: (any LLMSendService)?
    static var inFlightConversationIds = Set<UUID>()
}

@MainActor
enum ConversationTitleService {
    static func generateTitle(userMessage: String, conversationId: UUID) async -> String? {
        guard let llmSendService = ConversationTitleRuntimeBridge.llmSendService else { return nil }

        let titleMessages: [ChatMessage] = [
            ChatMessage(role: .user, conversationId: conversationId, content: userMessage),
        ]
        let config = llmSendService.resolveLLMConfig(
            for: conversationId,
            messages: titleMessages,
            allowsTools: false
        )

        let title = await ConversationTitleGenerator().generate(
            userMessage: userMessage,
            conversationId: conversationId,
            config: config
        ) { messages, config in
            try await llmSendService.streamLLMMessage(
                messages: messages,
                config: config,
                tools: nil,
                onChunk: { _ in },
                onRequestStart: { _ in }
            )
        }

        return title
    }
}
