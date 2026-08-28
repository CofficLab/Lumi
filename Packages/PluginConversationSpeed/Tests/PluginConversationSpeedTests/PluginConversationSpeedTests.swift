import Foundation
import Testing
import ProviderMessage
@testable import PluginConversationSpeed

@Test @MainActor func speedPluginInstantiates() async throws {
    let plugin = ConversationSpeedPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-speed")
}

@Test @MainActor func speedViewModelUpdatesFromMessageSnapshot() async throws {
    let conversationID = UUID()
    let message = Message(
        conversationID: conversationID,
        role: .assistant,
        content: "response",
        outputTokenCount: 120,
        streamingDurationMs: 6_000
    )
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(conversationID, messages: [message])

    #expect(viewModel.selectedConversationID == conversationID)
    #expect(viewModel.cachedTPS == 20)
    #expect(viewModel.speedHistory.count == 1)
    #expect(viewModel.outputTokens == 120)
}

@Test @MainActor func speedViewModelClearsWhenConversationIsDeselected() async throws {
    let viewModel = ConversationSpeedViewModel()
    let conversationID = UUID()
    let message = Message(
        conversationID: conversationID,
        role: .assistant,
        content: "response",
        outputTokenCount: 120,
        streamingDurationMs: 6_000
    )

    viewModel.selectConversation(conversationID, messages: [message])
    viewModel.selectConversation(nil, messages: [])

    #expect(viewModel.selectedConversationID == nil)
    #expect(viewModel.cachedTPS == nil)
    #expect(viewModel.speedHistory.isEmpty)
    #expect(viewModel.unavailabilityReason == .noConversationSelected)
}
