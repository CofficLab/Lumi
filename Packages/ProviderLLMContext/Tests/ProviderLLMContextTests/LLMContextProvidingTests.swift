import Foundation
import Testing
import ProviderMessage
@testable import ProviderLLMContext

@MainActor
struct LLMContextProvidingTests {
    @Test("上下文预算为输出、工具和安全余量预留空间")
    func contextBudgetReservesSpace() {
        let budget = LLMContextBudget(
            contextWindowTokens: 32_000,
            reservedOutputTokens: 8_000,
            toolSchemaTokens: 2_000,
            safetyMarginTokens: 1_000
        )

        #expect(budget.inputTokenLimit == 21_000)
        #expect(!budget.usesFallbackWindow)
    }

    @Test("未知窗口使用保守 fallback")
    func unknownContextWindowUsesFallback() {
        let budget = LLMContextBudget.conservative(contextWindowTokens: nil)

        #expect(budget.usesFallbackWindow)
        #expect(budget.inputTokenLimit == 22_000)
    }

    @Test("token 估算包含消息正文、reasoning 和工具参数")
    func tokenEstimatorIncludesMessageParts() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "回答",
            reasoningContent: "推理",
            toolCalls: [
                MessageToolCall(id: "call-1", name: "search", arguments: "{\"q\":\"Lumi\"}"),
            ]
        )

        #expect(LLMContextTokenEstimator.estimate(message: message) > 12)
    }

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
