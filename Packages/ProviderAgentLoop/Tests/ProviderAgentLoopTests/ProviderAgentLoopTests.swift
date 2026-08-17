import Foundation
import Testing
import ProviderMessage
import ProviderLLMVendors
@testable import ProviderAgentLoop

@Suite("ProviderAgentLoop")
@MainActor
struct ProviderAgentLoopTests {
    private final class TestLLMProvider: LLMProviding, @unchecked Sendable {
        let providerID = "test"
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "from provider", model: request.model)
        }
    }

    @Test("Loop 通过 responder 生成 assistant 消息并更新状态")
    func runsTurn() async throws {
        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = DefaultAgentLoopProviding(messages: messages)
        loop.setResponder { request in
            #expect(request.messages.count == 1)
            return "hello"
        }

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "hello")
        #expect(loop.state(for: conversationID) == .completed)
    }

    @Test("没有 responder 时返回明确失败")
    func missingResponder() async throws {
        let loop = DefaultAgentLoopProviding(messages: DefaultMessageManaging())
        let outcome = try await loop.runTurn(in: UUID())
        #expect(outcome == .failed("agent responder is not configured"))
    }

    @Test("Loop 可通过 LLM Provider 生成 assistant 消息")
    func runsWithLLMProvider() async throws {
        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = DefaultAgentLoopProviding(messages: messages, llmProvider: TestLLMProvider())

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "from provider")
    }

    @Test("createTurn 返回句柄并置为运行态（合并自 AgentTurn）")
    func createTurnSetsRunning() async throws {
        let loop = DefaultAgentLoopProviding(messages: DefaultMessageManaging())
        let conversationID = UUID()
        let handle = try await loop.createTurn(AgentTurnRequest(conversationID: conversationID, prompt: "hi"))
        #expect(loop.state(for: conversationID) == .running)
        #expect(loop.isRunning(for: conversationID))
        #expect(handle.id != UUID())
    }

    @Test("resumeTurn 可恢复被挂起/结束的回合（合并自 AgentTurn）")
    func resumeTurnRuns() async throws {
        let messages = DefaultMessageManaging()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "hi"), to: conversationID)
        let loop = DefaultAgentLoopProviding(messages: messages)
        loop.setResponder { _ in "resumed" }

        let outcome = try await loop.resumeTurn(in: conversationID)
        #expect(outcome == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "resumed")
        #expect(!loop.isRunning(for: conversationID))
    }

    @Test("AgentTurn 兼容类型别名指向 AgentLoop 状态机")
    func agentTurnCompatibility() async throws {
        let loop = DefaultAgentLoopProviding(messages: DefaultMessageManaging())
        let conversationID = UUID()
        #expect(AgentTurnState.idle == AgentLoopState.idle)
        #expect(AgentTurnOutcome.completed == AgentLoopOutcome.completed)
        #expect(loop.state(for: conversationID) == .idle)
    }
}
