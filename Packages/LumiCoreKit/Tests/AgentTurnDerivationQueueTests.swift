import Foundation
import LumiCoreKit
import Testing

@Suite("AgentTurnDerivation queue")
struct AgentTurnDerivationQueueTests {
    private let conversationId = UUID()

    @Test("idle with pending user message should start queued turn")
    func shouldStartQueuedTurnWhenIdle() {
        let messages = [
            ChatMessage(role: .user, conversationId: conversationId, content: "hi", queueStatus: .pending)
        ]
        #expect(AgentTurnDerivation.shouldStartQueuedTurn(messages: messages, phase: .idle))
        #expect(AgentTurnDerivation.shouldDequeueNextTurn(messages: messages, phase: .idle))
    }

    @Test("processing phase should not start queued turn")
    func shouldNotStartWhenProcessing() {
        let messages = [
            ChatMessage(role: .user, conversationId: conversationId, content: "hi", queueStatus: .pending)
        ]
        #expect(!AgentTurnDerivation.shouldStartQueuedTurn(messages: messages, phase: .processing))
    }

    @Test("firstPendingUserMessage returns earliest pending user")
    func firstPendingUserMessage() {
        let earlyId = UUID()
        let lateId = UUID()
        let early = ChatMessage(
            id: earlyId,
            role: .user,
            conversationId: conversationId,
            content: "first",
            timestamp: Date(timeIntervalSince1970: 1),
            queueStatus: .pending
        )
        let late = ChatMessage(
            id: lateId,
            role: .user,
            conversationId: conversationId,
            content: "second",
            timestamp: Date(timeIntervalSince1970: 2),
            queueStatus: .pending
        )
        let result = AgentTurnDerivation.firstPendingUserMessage(in: [late, early])
        #expect(result?.content == "first")
    }
}
