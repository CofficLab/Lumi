import Foundation
import Testing
@testable import PluginConversationStats

@MainActor
@Test func statisticsPackageCanBeImported() async throws {
    #expect(ConversationAgentTurnCountPlugin().id == "com.coffic.lumi.plugin.conversation-agent-turn-count")
}

@Test @MainActor func toolbarStatesForwardTypedEvents() {
    let conversationID = UUID()

    let agentState = AgentTurnStatusToolbarState()
    var agentEvents = 0
    let agentHandle = agentState.addObserver { _ in agentEvents += 1 }
    agentState.setSelectedConversationID(conversationID)
    agentState.markAgentLoopChanged(conversationID: conversationID)
    #expect(agentEvents == 2)
    agentHandle.cancel()
    agentState.markAgentLoopChanged(conversationID: conversationID)
    #expect(agentEvents == 2)
}

@Test @MainActor func agentTurnStateSeparatesObserversAndMakesCancellationIdempotent() {
    let conversationID = UUID()
    let state = AgentTurnStatusToolbarState()
    var firstObserverEvents = 0
    var secondObserverEvents = 0
    let firstHandle = state.addObserver { _ in firstObserverEvents += 1 }
    let secondHandle = state.addObserver { _ in secondObserverEvents += 1 }

    state.setSelectedConversationID(conversationID)
    state.setSelectedConversationID(conversationID)
    state.markAgentLoopChanged(conversationID: conversationID)
    firstHandle.cancel()
    firstHandle.cancel()
    state.setSelectedConversationID(nil)

    #expect(firstObserverEvents == 2)
    #expect(secondObserverEvents == 3)
    secondHandle.cancel()
}
