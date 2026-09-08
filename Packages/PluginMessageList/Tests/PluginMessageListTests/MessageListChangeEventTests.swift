import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageList

@MainActor
private final class BlockingMessageCapability: MessageListMessageCapability {
    var messagesByConversation: [UUID: [Message]] = [:]
    var blocksNextPageLoad = false
    private(set) var isWaitingForRelease = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        messagesByConversation[conversationID] ?? []
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        if blocksNextPageLoad {
            blocksNextPageLoad = false
            isWaitingForRelease = true
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
            isWaitingForRelease = false
        }
        return messagesByConversation[conversationID] ?? []
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        false
    }

    func releasePageLoad() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@MainActor
@Suite("Message list change events")
struct MessageListChangeEventTests {
    @Test("当前会话插入消息后直接更新展示行")
    func appliesInsertedMessageWithoutReload() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let conversationID = UUID()
        conversations.selectConversation(id: conversationID)

        let services = MessageListServices(
            conversations: MessageListConversationCapabilityAdapter(conversations: conversations),
            conversationState: nil,
            messages: MessageListMessageCapabilityAdapter(messages: messages),
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
        let viewModel = ListV2ViewModel(services: services)
        let detailedViewModel = ListV3ViewModel(services: services)
        let briefViewModel = ListV1ViewModel(services: services)
        let messageObserver = messages.addMessageChangeObserver { change in
            viewModel.handleMessageChange(change)
            detailedViewModel.handleMessageChange(change)
            briefViewModel.handleMessageChange(change)
        }
        defer { messageObserver.cancel() }

        await viewModel.activate(conversationID: conversationID)
        await detailedViewModel.activate(conversationID: conversationID)
        await briefViewModel.activate(conversationID: conversationID)
        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "直接显示"
        )
        messages.insertMessage(message, to: conversationID)

        #expect(viewModel.historyRows.contains { $0.id == message.id })
        #expect(viewModel.historyRows.last?.content == message.content)
        #expect(detailedViewModel.historyRows.contains { $0.id == message.id })
        #expect(detailedViewModel.historyRows.last?.content == message.content)
        #expect(briefViewModel.pendingUserMessages.contains { $0.id == message.id })
        #expect(briefViewModel.agentTurns.contains { $0.pendingAnchorMessageID == message.id })

        // 更新事件同样由插件注册的类型化观察器转发。
        messages.updateMessage(id: message.id, in: conversationID, content: "更新后的内容")
        for _ in 0..<100 {
            if viewModel.historyRows.last?.content == "更新后的内容",
               detailedViewModel.historyRows.last?.content == "更新后的内容" { break }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(viewModel.historyRows.last?.content == "更新后的内容")
        #expect(detailedViewModel.historyRows.last?.content == "更新后的内容")
    }

    @Test("切换会话时异步加载期间不保留旧会话消息")
    func clearsPreviousConversationWhileLoading() async {
        let conversations = DefaultConversationManager()
        let messages = BlockingMessageCapability()
        let firstConversationID = UUID()
        let secondConversationID = UUID()
        let firstMessage = Message(
            conversationID: firstConversationID,
            role: .assistant,
            content: "旧会话的 K3 消息",
            modelName: "kimi-k3"
        )
        let secondMessage = Message(
            conversationID: secondConversationID,
            role: .assistant,
            content: "新会话的 Qwen 消息",
            modelName: "qwen3.7-plus"
        )
        messages.messagesByConversation = [
            firstConversationID: [firstMessage],
            secondConversationID: [secondMessage],
        ]

        conversations.selectConversation(id: firstConversationID)
        let services = MessageListServices(
            conversations: MessageListConversationCapabilityAdapter(conversations: conversations),
            conversationState: nil,
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
        let viewModel = ListV2ViewModel(services: services)

        await viewModel.activate(conversationID: firstConversationID)
        #expect(viewModel.historyRows.contains { $0.id == firstMessage.id })

        conversations.selectConversation(id: secondConversationID)
        messages.blocksNextPageLoad = true
        let activation = Task { @MainActor in
            await viewModel.activate(conversationID: secondConversationID)
        }

        for _ in 0..<100 where !messages.isWaitingForRelease {
            await Task.yield()
        }

        #expect(messages.isWaitingForRelease)
        #expect(viewModel.isLoading)
        #expect(viewModel.historyRows.isEmpty)

        messages.releasePageLoad()
        await activation.value
        #expect(viewModel.historyRows.contains { $0.id == secondMessage.id })
        #expect(!viewModel.historyRows.contains { $0.id == firstMessage.id })
    }
}
