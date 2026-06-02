import Foundation
import Testing
@testable import PluginAgentTurnNotification

@MainActor
@Test func runtimeExtractsTurnFinishedConversationId() async throws {
    let conversationId = UUID()
    let notification = Notification(
        name: AgentTurnNotificationRuntime.turnFinishedNotificationName,
        object: conversationId
    )

    #expect(AgentTurnNotificationRuntime.conversationId(from: notification) == conversationId)
    #expect(AgentTurnNotificationRuntime.conversationId(from: Notification(name: .init("other"), object: conversationId)) == nil)
}

@MainActor
@Test func runtimeSelectConversationHandlerIsConfigurable() async throws {
    var selectedConversationId: UUID?
    let conversationId = UUID()

    AgentTurnNotificationRuntime.selectConversation = { selectedConversationId = $0 }
    AgentTurnNotificationRuntime.selectConversation(conversationId)

    #expect(selectedConversationId == conversationId)
}
