import Foundation
import ProviderAgentLoop
import ProviderMessage
import ProviderMessageStreaming
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

@MainActor
private final class StubStreamingCapability: MessageListStreamingCapability {
    var currentStage: MessageStreamingStage = .idle

    func streamingMessage(for conversationID: UUID) -> Message? { nil }
    func stage(for conversationID: UUID) -> MessageStreamingStage { currentStage }
}

@Test @MainActor func agentTurnViewModelPublishesProjectionChanges() async {
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
    let streaming = StubStreamingCapability()
    let services = MessageListServices(
        conversations: nil,
        conversationState: nil,
        developerMode: nil,
        messages: messages,
        rendering: nil,
        streaming: streaming,
        toolManager: nil,
        agentTurn: nil,
    )
    let item = AgentTurnPresentationItem(
        pendingUserMessages: [userMessage],
        statusMessage: nil
    )
    let viewModel = AgentTurnViewModel(services: services, item: item)

    await viewModel.refresh()
    #expect(viewModel.projection.userMessages.map(\.id) == [userMessage.id])
    messages.snapshot = [userMessage, statusMessage]
    streaming.currentStage = .thinking
    await viewModel.refresh()
    #expect(viewModel.projection.activity?.title == "正在思考…")
    #expect(viewModel.projection.processMessages.isEmpty)

    messages.snapshot = []
    await viewModel.refresh()
    #expect(viewModel.projection.userMessages.isEmpty)
}

@Test @MainActor func activeToolCallStaysInsideProcessDisclosure() {
    let conversationID = UUID()
    let turnID = UUID()
    let startedAt = Date()
    let userMessage = Message(
        conversationID: conversationID,
        role: .user,
        content: "检查项目",
        createdAt: startedAt
    )
    let toolMessage = Message(
        conversationID: conversationID,
        role: .assistant,
        content: "",
        createdAt: startedAt.addingTimeInterval(1),
        turnID: turnID,
        toolCalls: [
            MessageToolCall(
                id: "call-1",
                name: "apply_patch",
                arguments: "{}",
                displayDescription: "查看代码变更"
            )
        ]
    )
    let record = AgentTurnRecord(
        id: turnID,
        conversationID: conversationID,
        startedAt: startedAt,
        endedAt: nil,
        state: .running
    )
    let summary = AgentTurnSummaryBuilder()
        .build(records: [record], messages: [userMessage, toolMessage])
        .first!
    let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: true)

    let projection = AgentTurnViewModel.project(
        item: item,
        messages: [userMessage, toolMessage],
        conversationState: nil,
        streamingStage: .thinking
    )

    #expect(projection.processMessages.map(\.id) == [toolMessage.id])
    #expect(projection.lastMessage == nil)
    #expect(projection.activity?.title == "正在思考…")
}

@Test @MainActor func pendingAndRecordedTurnKeepStableListIdentity() {
    let conversationID = UUID()
    let turnID = UUID()
    let startedAt = Date()
    let userMessage = Message(
        id: UUID(),
        conversationID: conversationID,
        role: .user,
        content: "继续执行",
        createdAt: startedAt
    )
    let assistantMessage = Message(
        conversationID: conversationID,
        role: .assistant,
        content: "已完成",
        createdAt: startedAt.addingTimeInterval(1),
        turnID: turnID
    )
    let record = AgentTurnRecord(
        id: turnID,
        conversationID: conversationID,
        startedAt: startedAt.addingTimeInterval(1),
        endedAt: assistantMessage.createdAt,
        state: .completed
    )
    let summary = AgentTurnSummaryBuilder()
        .build(records: [record], messages: [userMessage, assistantMessage])
        .first!

    let pending = AgentTurnPresentationItem(
        pendingUserMessages: [userMessage],
        statusMessage: nil
    )
    let recorded = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

    #expect(pending.id == userMessage.id)
    #expect(recorded.id == pending.id)
}
