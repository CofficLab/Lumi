import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationSpeed

@Test @MainActor func conversationObserverLoadsAndTracksTheSelectedConversation() async throws {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let firstMessage = speedObserverMessage(conversationID: firstID, outputTokens: 80, durationMs: 4_000)
    messages.insertMessage(firstMessage, to: firstID)

    let viewModel = ConversationSpeedViewModel()
    let observer = SpeedConversationObserver(conversations: conversations, messages: messages, viewModel: viewModel)
    let firstLoaded = await waitUntil { viewModel.cachedTPS == 20 }

    #expect(firstLoaded)
    #expect(viewModel.selectedConversationID == firstID)

    let secondID = try conversations.createConversation(title: "Second", projectPath: nil, providerID: nil, modelName: nil)
    let secondMessage = speedObserverMessage(conversationID: secondID, outputTokens: 30, durationMs: 3_000)
    messages.insertMessage(secondMessage, to: secondID)
    let secondLoaded = await waitUntil { viewModel.cachedTPS == 10 }

    #expect(secondLoaded)
    #expect(viewModel.selectedConversationID == secondID)
    conversations.deselectConversation()
    #expect(viewModel.selectedConversationID == nil)
    #expect(viewModel.cachedTPS == nil)
    #expect(viewModel.unavailabilityReason == .noConversationSelected)

    observer.cancel()
}

@Test @MainActor func conversationObserverCancelStopsFurtherSelectionUpdates() async throws {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let viewModel = ConversationSpeedViewModel()
    let observer = SpeedConversationObserver(conversations: conversations, messages: messages, viewModel: viewModel)
    let firstLoaded = await waitUntil { viewModel.selectedConversationID == firstID }

    #expect(firstLoaded)
    observer.cancel()

    let secondID = try conversations.createConversation(title: "Second", projectPath: nil, providerID: nil, modelName: nil)
    try await Task.sleep(for: .milliseconds(20))

    #expect(viewModel.selectedConversationID == firstID)
    #expect(viewModel.selectedConversationID != secondID)
}

@Test @MainActor func messageObserverDebouncesSelectedConversationAndIgnoresOtherConversations() async throws {
    let conversations = DefaultConversationManager()
    let messages = DefaultMessageManager()
    let selectedID = try conversations.createConversation(title: "Selected", projectPath: nil, providerID: nil, modelName: nil)
    let otherID = try conversations.createConversation(title: "Other", projectPath: nil, providerID: nil, modelName: nil)
    conversations.selectConversation(id: selectedID)
    let viewModel = ConversationSpeedViewModel()
    viewModel.selectConversation(selectedID, messages: [])
    let observer = SpeedMessageObserver(messages: messages, viewModel: viewModel)

    messages.insertMessage(speedObserverMessage(conversationID: otherID, outputTokens: 500, durationMs: 1_000), to: otherID)
    try await Task.sleep(for: .milliseconds(180))
    #expect(viewModel.cachedTPS == nil)

    messages.insertMessage(speedObserverMessage(conversationID: selectedID, outputTokens: 80, durationMs: 4_000), to: selectedID)
    let updated = await waitUntil { viewModel.cachedTPS == 20 }

    #expect(updated)
    #expect(viewModel.speedHistory.count == 1)
    observer.cancel()
}

private func speedObserverMessage(conversationID: UUID, outputTokens: Int, durationMs: Double) -> Message {
    Message(
        conversationID: conversationID,
        role: .assistant,
        content: "response",
        outputTokenCount: outputTokens,
        streamingDurationMs: durationMs
    )
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
