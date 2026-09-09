import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListBrief

@MainActor
private final class StubMessageCapability: MessageListMessageCapability {
    var snapshot: [Message]

    init(snapshot: [Message]) {
        self.snapshot = snapshot
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        snapshot
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        snapshot
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        false
    }
}

@Test @MainActor func agentTurnViewModelForwardsProjectionEvents() async {
    let conversationID = UUID()
    let userMessage = Message(
        conversationID: conversationID,
        role: .user,
        content: "Hello"
    )
    let statusMessage = Message(
        conversationID: conversationID,
        role: .status,
        content: "Thinking"
    )
    let messages = StubMessageCapability(snapshot: [userMessage])
    let services = MessageListServices(
        conversations: nil,
        conversationState: nil,
        developerMode: nil,
        messages: messages,
        rendering: nil,
        streaming: nil,
        toolManager: nil,
        agentTurn: nil,
        promptSuggestions: nil,
        promptSuggestionExecutor: nil,
        project: nil,
        toolbar: nil,
        chat: nil
    )
    let item = AgentTurnPresentationItem(
        pendingUserMessages: [userMessage],
        statusMessage: nil
    )
    let viewModel = AgentTurnViewModel(services: services, item: item)

    var projections: [AgentTurnMessageProjection] = []
    let handle = viewModel.addObserver { event in
        switch event {
        case let .projectionChanged(projection):
            projections.append(projection)
        }
    }

    await viewModel.refresh()
    messages.snapshot = [userMessage, statusMessage]
    await viewModel.refresh()
    #expect(projections.count == 2)
    #expect(projections.last?.activityMessage?.content == "Thinking")

    handle.cancel()
    messages.snapshot = []
    await viewModel.refresh()
    #expect(projections.count == 2)
}
