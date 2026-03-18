import Combine
import Foundation
import MagicKit
import OSLog

@MainActor
final class ChatTimelineViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧭"
    nonisolated static let verbose = false
    nonisolated static let pageSize: Int = 10

    @Published private(set) var state = ConversationRenderState()

    private let agentProvider: AgentVM
    private let conversationVM: ConversationVM
    private var cancellables = Set<AnyCancellable>()
    private let metricUpdateEpsilon: CGFloat = 1

    init(agentProvider: AgentVM, conversationVM: ConversationVM) {
        self.agentProvider = agentProvider
        self.conversationVM = conversationVM
        self.state.selectedConversationId = conversationVM.selectedConversationId
        setupBindings()
    }

    var messages: [ChatMessage] {
        var rows = state.persistedMessages
        if let active = state.activeStreamingMessage, !rows.contains(where: { $0.id == active.id }) {
            rows.append(active)
        }
        return rows
    }

    var selectedConversationId: UUID? { state.selectedConversationId }
    var hasMoreMessages: Bool { state.hasMoreMessages }
    var isLoadingMore: Bool { state.isLoadingMore }
    var totalMessageCount: Int { state.totalMessageCount }
    var isNearBottom: Bool { state.isNearBottom }
    var shouldAutoFollow: Bool { state.shouldAutoFollow }

    func handleOnAppear() {
        Task { await loadMessagesForSelection() }
    }

    func handleConversationChanged() {
        Task { await didSelectConversation(conversationVM.selectedConversationId) }
    }

    func handleMessageSaved(_ message: ChatMessage, conversationId: UUID) {
        guard conversationId == state.selectedConversationId else { return }
        guard message.shouldDisplayInChatList() else {
            state.persistedMessages.removeAll { $0.id == message.id }
            refreshActiveStreamingMessage()
            return
        }

        if let idx = state.persistedMessages.firstIndex(where: { $0.id == message.id }) {
            state.persistedMessages[idx] = message
        } else if let insertIndex = state.persistedMessages.firstIndex(where: { $0.timestamp > message.timestamp }) {
            state.persistedMessages.insert(message, at: insertIndex)
        } else {
            state.persistedMessages.append(message)
        }

        state.totalMessageCount = max(state.totalMessageCount, state.persistedMessages.count)
        if let first = state.persistedMessages.first {
            state.oldestLoadedTimestamp = first.timestamp
        }
        refreshActiveStreamingMessage()
    }

    func handleLoadMore() {
        guard state.hasMoreMessages, !state.isLoadingMore, let conversationId = state.selectedConversationId else { return }

        Task { @MainActor in
            state.isLoadingMore = true
            defer { state.isLoadingMore = false }

            let result = await agentProvider.loadMessagesPage(
                forConversationId: conversationId,
                limit: Self.pageSize,
                beforeTimestamp: state.oldestLoadedTimestamp
            )

            if let firstMessage = result.messages.first {
                state.oldestLoadedTimestamp = firstMessage.timestamp
            }
            state.persistedMessages.insert(contentsOf: result.messages, at: 0)
            state.hasMoreMessages = result.hasMore
            refreshActiveStreamingMessage()
        }
    }

    func handleUserDidSendMessage() {
        state.shouldAutoFollow = true
    }

    func shouldPerformInitialScrollAfterMessageChange() -> Bool {
        guard !messages.isEmpty else { return false }
        if !state.hasPerformedInitialScroll {
            state.hasPerformedInitialScroll = true
            return true
        }
        return false
    }

    func enableAutoFollow() {
        state.shouldAutoFollow = true
    }

    func updateBottomMetrics(contentBottomY: CGFloat? = nil, viewportBottomY: CGFloat? = nil) {
        var didChangeMetric = false

        if let contentBottomY {
            if abs(contentBottomY - state.contentBottomY) > metricUpdateEpsilon {
                state.contentBottomY = contentBottomY
                didChangeMetric = true
            }
        }
        if let viewportBottomY {
            if abs(viewportBottomY - state.viewportBottomY) > metricUpdateEpsilon {
                state.viewportBottomY = viewportBottomY
                didChangeMetric = true
            }
        }

        guard didChangeMetric else { return }

        let distanceToBottom = state.contentBottomY - state.viewportBottomY
        let nearBottom = distanceToBottom <= 120

        if state.isNearBottom != nearBottom {
            state.isNearBottom = nearBottom
        }

        if nearBottom {
            if !state.shouldAutoFollow {
                state.shouldAutoFollow = true
            }
        } else if state.shouldAutoFollow {
            state.shouldAutoFollow = false
        }
    }

    private func setupBindings() {
        conversationVM.$selectedConversationId
            .removeDuplicates()
            .sink { [weak self] conversationId in
                guard let self else { return }
                Task { @MainActor in
                    await self.didSelectConversation(conversationId)
                }
            }
            .store(in: &cancellables)

        agentProvider.messageViewModel.$messages
            .sink { [weak self] _ in
                self?.refreshActiveStreamingMessage()
            }
            .store(in: &cancellables)
    }

    private func didSelectConversation(_ conversationId: UUID?) async {
        state.selectedConversationId = conversationId
        state.hasPerformedInitialScroll = false
        state.shouldAutoFollow = true
        state.isNearBottom = true
        await loadMessagesForSelection()
    }

    private func loadMessagesForSelection() async {
        guard let conversationId = state.selectedConversationId else {
            state.persistedMessages = []
            state.activeStreamingMessage = nil
            state.hasMoreMessages = false
            state.totalMessageCount = 0
            state.oldestLoadedTimestamp = nil
            return
        }

        state.isLoadingMore = true
        defer { state.isLoadingMore = false }

        let count = await agentProvider.getMessageCount(forConversationId: conversationId)
        state.totalMessageCount = count

        let result = await agentProvider.loadMessagesPage(
            forConversationId: conversationId,
            limit: Self.pageSize,
            beforeTimestamp: nil
        )

        if let firstMessage = result.messages.first {
            state.oldestLoadedTimestamp = firstMessage.timestamp
        } else {
            state.oldestLoadedTimestamp = nil
        }
        state.persistedMessages = result.messages
        state.hasMoreMessages = result.hasMore
        refreshActiveStreamingMessage()
    }

    private func refreshActiveStreamingMessage() {
        guard let conversationId = state.selectedConversationId,
              conversationId == conversationVM.selectedConversationId,
              let streamingId = agentProvider.currentStreamingMessageId,
              let liveMessage = agentProvider.messages.first(where: { $0.id == streamingId })
        else {
            state.activeStreamingMessage = nil
            return
        }

        if state.persistedMessages.contains(where: { $0.id == liveMessage.id }) {
            state.activeStreamingMessage = nil
            return
        }
        state.activeStreamingMessage = liveMessage
    }
}
