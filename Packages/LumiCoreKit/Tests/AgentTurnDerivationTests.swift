import Foundation
import AgentToolKit
import LumiCoreKit
import Testing

@Suite("AgentTurnDerivation")
struct AgentTurnDerivationTests {
    private let conversationId = UUID()

    @Test("user message should request LLM")
    func userMessageRequestsLLM() {
        let messages = [ChatMessage(role: .user, conversationId: conversationId, content: "hi")]
        #expect(AgentTurnDerivation.shouldRequestLLM(messages: messages))
        #expect(!AgentTurnDerivation.shouldExecuteTools(messages: messages, phase: .processing))
    }

    @Test("assistant with pending tools should execute tools")
    func assistantPendingTools() {
        let toolCall = ToolCall(id: "t1", name: "read", arguments: "{}")
        let messages = [
            ChatMessage(role: .assistant, conversationId: conversationId, content: "", toolCalls: [toolCall])
        ]
        #expect(!AgentTurnDerivation.shouldRequestLLM(messages: messages))
        #expect(AgentTurnDerivation.shouldExecuteTools(messages: messages, phase: .processing))
    }

    @Test("assistant with completed tools should request LLM")
    func assistantCompletedToolsRequestLLM() {
        var toolCall = ToolCall(id: "t1", name: "read", arguments: "{}")
        toolCall.result = ToolCallResult(content: "ok")
        let messages = [
            ChatMessage(role: .assistant, conversationId: conversationId, content: "", toolCalls: [toolCall])
        ]
        #expect(AgentTurnDerivation.shouldRequestLLM(messages: messages))
    }

    @Test("assistant without tools completes turn")
    func turnComplete() {
        let messages = [
            ChatMessage(role: .assistant, conversationId: conversationId, content: "done")
        ]
        #expect(AgentTurnDerivation.isTurnComplete(messages: messages))
    }
}
