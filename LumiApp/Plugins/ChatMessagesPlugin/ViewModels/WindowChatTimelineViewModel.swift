import Combine
import ToolKit
import Foundation

@MainActor
final class WindowChatTimelineViewModel: ObservableObject {
    nonisolated static let pageSize: Int = 10

    @Published private(set) var state = ConversationRenderState()

    private let chatHistoryService: ChatHistoryService
    private let conversationVM: WindowConversationVM
    private var cancellables = Set<AnyCancellable>()

    init(
        chatHistoryService: ChatHistoryService,
        conversationVM: WindowConversationVM
    ) {
        self.chatHistoryService = chatHistoryService
        self.conversationVM = conversationVM
        self.state.selectedConversationId = conversationVM.selectedConversationId
        setupBindings()
    }

    var messages: [ChatMessage] {
        var rows = mergedVisibleMessages()
        if let active = state.activeStreamingMessage, !rows.contains(where: { $0.id == active.id }) {
            rows.append(active)
        }
        return rows
    }

    var persistedMessages: [ChatMessage] { state.persistedMessages }
    var visibleMessages: [ChatMessage] { mergedVisibleMessages() }
    var activeStreamingMessage: ChatMessage? { state.activeStreamingMessage }

    var selectedConversationId: UUID? { state.selectedConversationId }
    var hasMoreMessages: Bool { state.hasMoreMessages }
    var isLoadingMore: Bool { state.isLoadingMore }
    var totalMessageCount: Int { state.totalMessageCount }
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

    func toolOutputs(for toolCallID: String) -> [ChatMessage] {
        state.toolOutputsByToolCallID[toolCallID] ?? []
    }

    func hasLoadedToolOutputs(for message: ChatMessage) -> Bool {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else { return false }
        let ids = toolCalls.map(\.id)
        return !ids.isEmpty && ids.allSatisfy { state.loadedToolCallIDs.contains($0) }
    }

    func hasLoadedToolOutput(for toolCallID: String) -> Bool {
        state.loadedToolCallIDs.contains(toolCallID)
    }

    func isLoadingToolOutputs(for message: ChatMessage) -> Bool {
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else { return false }
        return toolCalls.map(\.id).contains { state.loadingToolCallIDs.contains($0) }
    }

    func isLoadingToolOutput(for toolCallID: String) -> Bool {
        state.loadingToolCallIDs.contains(toolCallID)
    }

    func loadToolOutput(for message: ChatMessage, toolCallID: String, forceReload: Bool = false) {
        guard let toolCalls = message.toolCalls, toolCalls.contains(where: { $0.id == toolCallID }) else { return }
        loadToolOutputs(for: message, toolCallIDs: [toolCallID], forceReload: forceReload)
    }

    func loadToolOutputs(for message: ChatMessage, forceReload: Bool = false) {
        let ids = message.toolCalls?.map(\.id) ?? []
        loadToolOutputs(for: message, toolCallIDs: ids, forceReload: forceReload)
    }

    private func loadToolOutputs(for message: ChatMessage, toolCallIDs: [String], forceReload: Bool) {
        guard let conversationId = state.selectedConversationId,
              !toolCallIDs.isEmpty else { return }

        let requestedIDs = Array(Set(toolCallIDs))
        let targetIDs: [String]
        if forceReload {
            targetIDs = requestedIDs
        } else {
            targetIDs = requestedIDs.filter { !state.loadedToolCallIDs.contains($0) && !state.loadingToolCallIDs.contains($0) }
        }

        guard !targetIDs.isEmpty else { return }
        targetIDs.forEach { state.loadingToolCallIDs.insert($0) }

        Task { @MainActor in
            let loadedMessages = await chatHistoryService.loadToolOutputMessages(
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
        objectWillChange.send()
        state.queuedMessages.removeAll { $0.id == message.id }
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

    func handleMessageQueued(_ message: ChatMessage) {
        guard message.conversationId == state.selectedConversationId else {
            return
        }
        guard message.shouldDisplayInChatList() else {
            return
        }
        guard !state.persistedMessages.contains(where: { $0.id == message.id }) else {
            return
        }

        objectWillChange.send()
        if let idx = state.queuedMessages.firstIndex(where: { $0.id == message.id }) {
            state.queuedMessages[idx] = message
        } else if let insertIndex = state.queuedMessages.firstIndex(where: { $0.timestamp > message.timestamp }) {
            state.queuedMessages.insert(message, at: insertIndex)
        } else {
            state.queuedMessages.append(message)
        }

        refreshActiveStreamingMessage()
    }

    func removeQueuedMessage(id messageId: UUID) {
        state.queuedMessages.removeAll { $0.id == messageId }
        refreshActiveStreamingMessage()
    }

    func handleLoadMore() {
        guard state.hasMoreMessages, !state.isLoadingMore, let conversationId = state.selectedConversationId else { return }

        Task { @MainActor in
            state.isLoadingMore = true
            defer { state.isLoadingMore = false }

            let result = await chatHistoryService.loadMessagesPage(
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

    /// 从数据库和内存中删除指定消息
    /// - Parameter messageId: 要删除的消息 ID
    func deleteMessage(_ messageId: UUID) {
        guard let conversationId = state.selectedConversationId else { return }

        Task { @MainActor in
            let deleted = await chatHistoryService.deleteMessagesAsync(
                messageIds: [messageId],
                conversationId: conversationId
            )
            guard deleted > 0 else { return }

            state.persistedMessages.removeAll { $0.id == messageId }
            state.totalMessageCount = max(0, state.totalMessageCount - 1)
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

    func disableAutoFollow() {
        state.shouldAutoFollow = false
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

        NotificationCenter.default.publisher(for: .messageSaved)
            .sink { [weak self] notification in
                guard let self,
                      let message = notification.object as? ChatMessage,
                      let conversationId = notification.userInfo?["conversationId"] as? UUID
                else { return }

                self.handleMessageSaved(message, conversationId: conversationId)
            }
            .store(in: &cancellables)
    }

    private func didSelectConversation(_ conversationId: UUID?) async {
        state.selectedConversationId = conversationId
        state.hasPerformedInitialScroll = false
        state.shouldAutoFollow = true
        state.toolOutputsByToolCallID = [:]
        state.loadedToolCallIDs = []
        state.loadingToolCallIDs = []
        await loadMessagesForSelection()
    }

    private func loadMessagesForSelection() async {
        guard let conversationId = state.selectedConversationId else {
            state.persistedMessages = []
            state.queuedMessages = []
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

        let count = await chatHistoryService.getMessageCount(forConversationId: conversationId)
        state.totalMessageCount = count

        let result = await chatHistoryService.loadMessagesPage(
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
        state.queuedMessages.removeAll()
        state.hasMoreMessages = result.hasMore
        refreshActiveStreamingMessage()
    }

    private func mergedVisibleMessages() -> [ChatMessage] {
        var rows = state.persistedMessages
        for message in state.queuedMessages where !rows.contains(where: { $0.id == message.id }) {
            if let insertIndex = rows.firstIndex(where: { $0.timestamp > message.timestamp }) {
                rows.insert(message, at: insertIndex)
            } else {
                rows.append(message)
            }
        }
        return rows
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
        state.activeStreamingMessage = nil
    }
}
