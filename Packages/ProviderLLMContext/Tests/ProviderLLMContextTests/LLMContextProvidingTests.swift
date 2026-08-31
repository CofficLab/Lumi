import Foundation
import Testing
import ProviderMessage
@testable import ProviderLLMContext

@MainActor
struct LLMContextProvidingTests {
    @Test("透传 Provider 保留消息顺序和内容")
    func passthroughPreservesMessages() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "第一条"),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: "第二条"),
            to: conversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.map(\.content) == ["第一条", "第二条"])
        #expect(result.map(\.role) == [.user, .assistant])
    }

    @Test("透传 Provider 不返回其他会话的消息")
    func passthroughScopesConversation() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()
        let otherConversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "目标会话"),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: otherConversationID, role: .user, content: "其他会话"),
            to: otherConversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.map(\.content) == ["目标会话"])
    }
}
