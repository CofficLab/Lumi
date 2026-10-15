import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import Testing
@testable import PluginConversationStats

@Suite("Conversation statistics observers")
@MainActor
struct ObserverTests {
    @Test("agent-turn observer forwards every event's conversation and stops after cancellation")
    func agentTurnObserverLifecycle() throws {
        let conversations = DefaultConversationManager()
        let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
        let secondID = UUID()
        let agentLoop = MockAgentLoopProvider()
        var selectedIDs: [String] = []
        var changedIDs: [UUID] = []
        let observer = AgentTurnStatusObserver(
            conversations: conversations,
            agentLoop: agentLoop,
            onConversationChange: { selectedIDs.append($0?.uuidString ?? "none") },
            onAgentLoopChange: { changedIDs.append($0) }
        )

        let turnID = UUID()
        agentLoop.notify(.started(conversationID: firstID, turnID: turnID))
        agentLoop.notify(.toolCallsReceived(conversationID: secondID, turnID: turnID, assistantMessageID: UUID(), toolCalls: []))
        agentLoop.notify(.llmResponseReceived(conversationID: firstID, turnID: turnID, toolCalls: []))
        agentLoop.notify(.suspended(
            conversationID: secondID,
            turnID: turnID,
            suspension: AgentLoopSuspension(suspensionID: "s", conversationID: secondID, kind: "ask", payload: "{}")
        ))
        agentLoop.notify(.completed(conversationID: firstID, turnID: turnID))
        agentLoop.notify(.failed(conversationID: secondID, turnID: turnID, reason: "failed"))
        agentLoop.notify(.cancelled(conversationID: firstID, turnID: turnID))
        conversations.deselectConversation()

        #expect(changedIDs == [firstID, secondID, firstID, secondID, firstID, secondID, firstID])
        #expect(selectedIDs == [firstID.uuidString, "none"])

        observer.cancel()
        agentLoop.notify(.completed(conversationID: secondID, turnID: turnID))
        conversations.selectConversation(id: firstID)
        #expect(changedIDs.count == 7)
        #expect(selectedIDs == [firstID.uuidString, "none"])
    }
}

@MainActor
private final class MockAgentLoopProvider: AgentLoopProviding {
    private var observer: ((AgentLoopEvent) -> Void)?

    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        observer = callback
        return MockAgentLoopObserverHandle { [weak self] in self?.observer = nil }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

    func notify(_ event: AgentLoopEvent) {
        observer?(event)
    }
}

@MainActor
private final class MockAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }
}
