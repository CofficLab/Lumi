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
