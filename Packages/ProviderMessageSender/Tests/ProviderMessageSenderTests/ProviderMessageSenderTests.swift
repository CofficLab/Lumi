import Testing
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
@testable import ProviderMessageSender

@Suite("ProviderMessageSender")
@MainActor
struct ProviderMessageSenderTests {
    @Test("发送消息会创建会话、落用户消息并运行 Agent Loop")
    func sendsMessageThroughLoop() async throws {
        let conversations = DefaultConversationManaging()
        let messages = DefaultMessageManaging()
        let loop = DefaultAgentLoopProviding(messages: messages)
        loop.setResponder { _ in "response" }
        let sender = DefaultMessageSendingProviding(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )

        try await sender.sendMessage("hello", conversationID: nil)
        let id = try #require(conversations.selectedConversationID)
        #expect(messages.messages(for: id).map(\.content) == ["hello", "response"])
        #expect(sender.isSending == false)
    }
}
