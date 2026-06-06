import Foundation
import LumiCoreKit
import Testing

@Suite("SendQueue derivation gates")
struct SendQueuePluginTests {
    private let conversationId = UUID()

    @Test("should dequeue when idle and pending exists")
    func dequeueGate() {
        let messages = [
            ChatMessage(role: .user, conversationId: conversationId, content: "hi", queueStatus: .pending)
        ]
        #expect(AgentTurnDerivation.shouldDequeueNextTurn(messages: messages, phase: .idle))
    }

    @Test("should not dequeue when already processing")
    func noDequeueWhenBusy() {
        let messages = [
            ChatMessage(role: .user, conversationId: conversationId, content: "hi", queueStatus: .pending)
        ]
        #expect(!AgentTurnDerivation.shouldDequeueNextTurn(messages: messages, phase: .processing))
    }
}
