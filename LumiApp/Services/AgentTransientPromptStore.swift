import Foundation

/// 首轮 LLM 请求使用的临时 system prompts（SendPipeline 产出，MessageSender 消费）。
@MainActor
final class AgentTransientPromptStore {
    static let shared = AgentTransientPromptStore()

    private var promptsByConversation: [UUID: [String]] = [:]

    private init() {}

    func store(_ prompts: [String], for conversationId: UUID) {
        guard !prompts.isEmpty else { return }
        promptsByConversation[conversationId] = prompts
    }

    func consume(for conversationId: UUID) -> [String] {
        let prompts = promptsByConversation[conversationId] ?? []
        promptsByConversation[conversationId] = nil
        return prompts
    }

    func clear(for conversationId: UUID) {
        promptsByConversation[conversationId] = nil
    }

    func clearAll() {
        promptsByConversation.removeAll()
    }
}
