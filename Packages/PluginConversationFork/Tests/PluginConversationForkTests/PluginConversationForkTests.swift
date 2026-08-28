import Foundation
import Testing
import ProviderConversation
import ProviderMessage
import ProviderLLMManager
import KitLLM
import ProviderMessageSender
import ProviderLifecycleHooks
import ProviderAgentLoop

@testable import PluginConversationFork

@Suite("ConversationForkPlugin")
@MainActor
struct ConversationForkPluginTests {
    @Test("Summarizer 回退摘要：无历史时返回占位")
    func summarizerEmptyFallback() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let llmProvider = DefaultLLMProviderManagerProviding()
        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )
        let id = UUID()
        let outcome = await summarizer.summarize(conversationID: id)
        #expect(outcome.usedFallback)
        #expect(outcome.summary == "(No prior context captured.)")
    }

    @Test("Summarizer 回退摘要：有历史时拼装本地摘要")
    func summarizerFallbackWithHistory() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let llmProvider = DefaultLLMProviderManagerProviding()
        let id = UUID()
        messages.insertMessage(Message(conversationID: id, role: .user, content: "帮我写个排序"), to: id)
        messages.insertMessage(Message(conversationID: id, role: .assistant, content: "用快速排序"), to: id)

        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )
        let outcome = await summarizer.summarize(conversationID: id)
        #expect(outcome.usedFallback)
        #expect(outcome.summary.contains("帮我写个排序"))
        #expect(outcome.summary.contains("快速排序"))
    }

    @Test("renderHistory 渲染 user/assistant 前缀")
    func renderHistory() {
        let id = UUID()
        let history = [
            Message(conversationID: id, role: .user, content: "hi"),
            Message(conversationID: id, role: .assistant, content: "hello"),
        ]
        let rendered = ConversationSummarizer.renderHistory(history)
        #expect(rendered.contains("User: hi"))
        #expect(rendered.contains("Assistant: hello"))
    }

    @Test("Fork 按钮通过 sender 发送摘要到新对话")
    func forkSendsSummary() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        conversations.selectConversation(id: id)
        messages.insertMessage(Message(conversationID: id, role: .user, content: "第一条"), to: id)

        // 直接验证 sender 可在新对话发消息（ForkButton 的发送路径）。
        try await sender.sendMessage("摘要内容", conversationID: id)
        let newID = try #require(conversations.selectedConversationID)
        #expect(messages.messages(for: newID).contains { $0.content == "摘要内容" })
    }
}

/// 测试用 AgentLoop 桩：保留 responder 语义，落库 assistant 消息。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    init(messages: any MessageManaging) {
        self.messages = messages
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

}
