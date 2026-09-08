import Combine
import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageStreaming
import Testing
@testable import PluginMessageList

@MainActor
private final class TestMessageCapability: MessageListMessageCapability {
    var messages: [Message]

    init(messages: [Message] = []) {
        self.messages = messages
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        messages.filter { $0.conversationID == conversationID }
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        await messagesSnapshot(in: conversationID)
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
private final class TestStreamingCapability: MessageListStreamingCapability {
    var currentStage: MessageStreamingStage = .idle

    func streamingMessage(for conversationID: UUID) -> Message? { nil }

    func stage(for conversationID: UUID) -> MessageStreamingStage {
        currentStage
    }
}

@MainActor
@Suite("V1 streaming projection")
struct AgentTurnViewModelTests {
    @Test("V1 不把流式临时回复加入展示投影")
    func streamingMessageIsNotProjected() {
        let conversationID = UUID()
        let turnID = UUID()
        let item = AgentTurnPresentationItem(
            recorded: AgentTurnSummaryItem(
                record: AgentTurnRecord(
                    id: turnID,
                    conversationID: conversationID,
                    startedAt: Date(timeIntervalSince1970: 10),
                    endedAt: nil,
                    state: .running
                ),
                userMessage: nil,
                processMessages: [],
                message: Message(
                    conversationID: conversationID,
                    role: .status,
                    content: "…",
                    createdAt: Date(timeIntervalSince1970: 10),
                    turnID: turnID
                )
            ),
            acceptsLiveActivity: true
        )
        let streamingMessage = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "正在生成的半截回复",
            createdAt: Date(timeIntervalSince1970: 11),
            turnID: turnID
        )

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [],
            streamingMessage: streamingMessage,
            streamingStage: .generating
        )

        #expect(projection.lastMessage == nil)
        #expect(projection.processMessages.isEmpty)
        #expect(projection.activityMessage?.content == "正在生成回复…")
    }

    @Test("投影未变化时刷新不发布 SwiftUI 更新")
    func unchangedProjectionDoesNotPublish() async {
        let conversationID = UUID()
        let userMessage = Message(
            conversationID: conversationID,
            role: .user,
            content: "固定消息"
        )
        let streaming = TestStreamingCapability()
        streaming.currentStage = .generating
        let services = MessageListServices(
            conversations: nil,
            conversationState: nil,
            messages: TestMessageCapability(messages: [userMessage]),
            rendering: nil,
            streaming: streaming,
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
        var changeCount = 0
        let cancellable = viewModel.objectWillChange.sink { changeCount += 1 }

        await viewModel.activate()
        let countAfterActivate = changeCount
        await viewModel.refresh()

        #expect(changeCount == countAfterActivate)
        cancellable.cancel()
    }

    @Test("V1 忽略同一流式阶段内的重复通知")
    func repeatedStreamingUpdatesDoNotRefresh() async {
        let conversationID = UUID()
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let streaming = TestStreamingCapability()
        conversations.selectConversation(id: conversationID)

        let services = MessageListServices(
            conversations: MessageListConversationCapabilityAdapter(conversations: conversations),
            conversationState: nil,
            messages: MessageListMessageCapabilityAdapter(messages: messages),
            rendering: nil,
            streaming: streaming,
            toolManager: nil,
            agentTurn: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            project: nil,
            toolbar: nil,
            chat: nil
        )
        let listViewModel = ListV1ViewModel(services: services)
        await listViewModel.activate(conversationID: conversationID)

        let userMessage = Message(
            conversationID: conversationID,
            role: .user,
            content: "触发回合"
        )
        messages.insertMessage(userMessage, to: conversationID)
        listViewModel.handleMessageChange(.inserted(userMessage, conversationID: conversationID))
        guard let item = listViewModel.agentTurns.first else {
            Issue.record("未生成待处理的 V1 Agent Turn")
            return
        }
        let turnViewModel = listViewModel.agentTurnViewModel(for: item)
        await turnViewModel.activate()

        var changeCount = 0
        let cancellable = turnViewModel.objectWillChange.sink { changeCount += 1 }
        streaming.currentStage = .generating
        listViewModel.handleStreamingChange(.updated(conversationID))
        await Task.yield()
        await Task.yield()
        let countAfterStageChange = changeCount

        listViewModel.handleStreamingChange(.updated(conversationID))
        await Task.yield()

        #expect(countAfterStageChange > 0)
        #expect(changeCount == countAfterStageChange)
        cancellable.cancel()
    }
}
