import Foundation
import Testing
@testable import PluginConversationStats

@MainActor
@Test func statisticsPackageCanBeImported() async throws {
    #expect(ConversationMessageCountPlugin().id == "com.coffic.lumi.plugin.conversation-message-count")
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

    let messageState = MessageCountToolbarState()
    var messageEvents = 0
    let messageHandle = messageState.addObserver { _ in messageEvents += 1 }
    messageState.setSelectedConversationID(conversationID)
    messageState.markMessagesChanged(conversationID: conversationID)
    #expect(messageEvents == 2)
    messageHandle.cancel()
    messageState.markMessagesChanged(conversationID: conversationID)
    #expect(messageEvents == 2)
}

@Test @MainActor func toolbarStatesSuppressRepeatedSelectionAndForwardClearing() {
    let firstConversationID = UUID()
    let secondConversationID = UUID()
    let messageState = MessageCountToolbarState()
    var messageEvents: [String] = []
    let messageHandle = messageState.addObserver { event in
        switch event {
        case .selectedConversationChanged(let id):
            messageEvents.append("selection:\(id?.uuidString ?? "none")")
        case .messagesChanged(let id):
            messageEvents.append("messages:\(id.uuidString)")
        }
    }

    messageState.setSelectedConversationID(firstConversationID)
    messageState.setSelectedConversationID(firstConversationID)
    messageState.setSelectedConversationID(nil)
    messageState.markMessagesChanged(conversationID: secondConversationID)

    #expect(messageEvents == [
        "selection:\(firstConversationID.uuidString)",
        "selection:none",
        "messages:\(secondConversationID.uuidString)",
    ])
    messageHandle.cancel()
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
