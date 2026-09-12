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

@Test @MainActor func speedViewModelIgnoresRefreshForAnotherConversation() {
    let selectedConversationID = UUID()
    let staleConversationID = UUID()
    let selectedMessage = Message(
        conversationID: selectedConversationID,
        role: .assistant,
        content: "selected",
        outputTokenCount: 120,
        streamingDurationMs: 6_000
    )
    let staleMessage = Message(
        conversationID: staleConversationID,
        role: .assistant,
        content: "stale",
        outputTokenCount: 1,
        streamingDurationMs: 1_000
    )
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(selectedConversationID, messages: [selectedMessage])
    viewModel.refresh(conversationID: staleConversationID, messages: [staleMessage])

    #expect(viewModel.selectedConversationID == selectedConversationID)
    #expect(viewModel.cachedTPS == 20)
    #expect(viewModel.speedHistory.map(\.id) == [selectedMessage.id])
}

@Test @MainActor func speedViewModelClearsPreviousConversationDetailsWhenSelectionChanges() {
    let firstConversationID = UUID()
    let secondConversationID = UUID()
    let message = Message(
        conversationID: firstConversationID,
        role: .assistant,
        content: "response",
        providerID: "provider-a",
        modelName: "model-a",
        outputTokenCount: 120,
        streamingDurationMs: 6_000
    )
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(firstConversationID, messages: [message])
    viewModel.selectConversation(secondConversationID, messages: [])

    #expect(viewModel.selectedConversationID == secondConversationID)
    #expect(viewModel.cachedTPS == nil)
    #expect(viewModel.speedHistory.isEmpty)
    #expect(viewModel.modelName == nil)
    #expect(viewModel.providerID == nil)
    #expect(viewModel.outputTokens == nil)
    #expect(viewModel.unavailabilityReason == .waitingForResponse)
}

@Test @MainActor func speedViewModelUsesAssistantMetricsInsteadOfUserMessageMetadata() {
    let conversationID = UUID()
    let assistant = Message(
        conversationID: conversationID,
        role: .assistant,
        content: "waiting response",
        modelName: "assistant-model",
        outputTokenCount: nil,
        streamingDurationMs: nil
    )
    let userWithUnexpectedOutputMetadata = Message(
        conversationID: conversationID,
        role: .user,
        content: "prompt",
        modelName: "user-model",
        outputTokenCount: 100,
        streamingDurationMs: 1_000
    )
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(conversationID, messages: [assistant, userWithUnexpectedOutputMetadata])

    #expect(viewModel.cachedTPS == nil)
    #expect(viewModel.speedHistory.isEmpty)
    #expect(viewModel.modelName == "assistant-model")
    #expect(viewModel.outputTokens == nil)
    #expect(viewModel.unavailabilityReason == .missingOutputTokensAndDuration)
}
