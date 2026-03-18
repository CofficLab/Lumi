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
    private let minMetricUpdateInterval: TimeInterval = 0.05
    private var lastMetricUpdateAt: Date = .distantPast

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

    var persistedMessages: [ChatMessage] { state.persistedMessages }
    var activeStreamingMessage: ChatMessage? { state.activeStreamingMessage }

    var selectedConversationId: UUID? { state.selectedConversationId }
    var hasMoreMessages: Bool { state.hasMoreMessages }
    var isLoadingMore: Bool { state.isLoadingMore }
    var totalMessageCount: Int { state.totalMessageCount }
    var isNearBottom: Bool { state.isNearBottom }
    var shouldAutoFollow: Bool { state.shouldAutoFollow }

    func toolOutputs(for message: ChatMessage) -> [ChatMessage] {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else { return [] }
        let validIDs = Set(toolCalls.map(\.id))
        guard !validIDs.isEmpty else { return [] }

        return validIDs
            .compactMap { state.toolOutputsByToolCallID[$0] }
            .flatMap { $0 }
            .sorted { lhs, rhs in
                if lhs.timestamp == rhs.timestamp {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.timestamp < rhs.timestamp
            }
    }

    func hasLoadedToolOutputs(for message: ChatMessage) -> Bool {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else { return false }
        let ids = toolCalls.map(\.id)
        return !ids.isEmpty && ids.allSatisfy { state.loadedToolCallIDs.contains($0) }
    }

    func isLoadingToolOutputs(for message: ChatMessage) -> Bool {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else { return false }
        return toolCalls.map(\.id).contains { state.loadingToolCallIDs.contains($0) }
    }

    func loadToolOutputs(for message: ChatMessage, forceReload: Bool = false) {
        guard let conversationId = state.selectedConversationId,
              let toolCalls = message.toolCalls, !toolCalls.isEmpty else { return }

        let requestedIDs = Array(Set(toolCalls.map(\.id)))
        let targetIDs: [String]
        if forceReload {
            targetIDs = requestedIDs
        } else {
            targetIDs = requestedIDs.filter { !state.loadedToolCallIDs.contains($0) && !state.loadingToolCallIDs.contains($0) }
        }

        guard !targetIDs.isEmpty else { return }
        targetIDs.forEach { state.loadingToolCallIDs.insert($0) }

        Task { @MainActor in
            let loadedMessages = await agentProvider.loadToolOutputMessages(
                forConversationId: conversationId,
                toolCallIDs: targetIDs
            )

            mergeToolOutputs(loadedMessages)
            targetIDs.forEach {
                state.loadingToolCallIDs.remove($0)
                state.loadedToolCallIDs.insert($0)
            }
        }
    }

    func handleOnAppear() {
        Task { await loadMessagesForSelection() }
    }

    func handleConversationChanged() {
        Task { await didSelectConversation(conversationVM.selectedConversationId) }
    }

    func handleMessageSaved(_ message: ChatMessage, conversationId: UUID) {
        guard conversationId == state.selectedConversationId else { return }
        if message.role == .tool || message.isToolOutput {
            if let toolCallID = message.toolCallID,
               state.loadedToolCallIDs.contains(toolCallID) {
                mergeToolOutputs([message])
            }
        }
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
        let now = Date()
        if now.timeIntervalSince(lastMetricUpdateAt) < minMetricUpdateInterval {
            return
        }

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
        lastMetricUpdateAt = now

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

        agentProvider.$streamingRenderVersion
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
        state.toolOutputsByToolCallID = [:]
        state.loadedToolCallIDs = []
        state.loadingToolCallIDs = []
        await loadMessagesForSelection()
    }

    private func loadMessagesForSelection() async {
        guard let conversationId = state.selectedConversationId else {
            state.persistedMessages = []
            state.activeStreamingMessage = nil
            state.hasMoreMessages = false
            state.totalMessageCount = 0
            state.oldestLoadedTimestamp = nil
            state.toolOutputsByToolCallID = [:]
            state.loadedToolCallIDs = []
            state.loadingToolCallIDs = []
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

    private func mergeToolOutputs(_ messages: [ChatMessage]) {
        guard !messages.isEmpty else { return }

        for message in messages {
            guard let toolCallID = message.toolCallID else { continue }
            var outputs = state.toolOutputsByToolCallID[toolCallID] ?? []
            if let idx = outputs.firstIndex(where: { $0.id == message.id }) {
                outputs[idx] = message
            } else if let insertIndex = outputs.firstIndex(where: { $0.timestamp > message.timestamp }) {
                outputs.insert(message, at: insertIndex)
            } else {
                outputs.append(message)
            }
            state.toolOutputsByToolCallID[toolCallID] = outputs
        }
    }

    private func refreshActiveStreamingMessage() {
        guard let conversationId = state.selectedConversationId,
              conversationId == conversationVM.selectedConversationId,
              let liveMessage = agentProvider.activeStreamingMessageForSelectedConversation
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
