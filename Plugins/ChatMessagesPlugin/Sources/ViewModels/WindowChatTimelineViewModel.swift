import Combine
import Foundation
import LumiCoreKit

@MainActor
public final class WindowChatTimelineViewModel: ObservableObject {
    public nonisolated static let pageSize: Int = 10

    @Published public private(set) var state = ConversationRenderState()

    private var conversationVM: LumiCoreKit.WindowConversationVM?
    private var cancellables = Set<AnyCancellable>()

    public init() {}

    public var messages: [ChatMessage] {
        var rows = mergedVisibleMessages()
        if let active = state.activeStreamingMessage,
           !rows.contains(where: { $0.id == active.id }) {
            rows.append(active)
        }
        return rows
    }

    public var persistedMessages: [ChatMessage] { state.persistedMessages }
    public var visibleMessages: [ChatMessage] { mergedVisibleMessages() }
    public var activeStreamingMessage: ChatMessage? { state.activeStreamingMessage }
    public var selectedConversationId: UUID? { state.selectedConversationId }
    public var hasMoreMessages: Bool { state.hasMoreMessages }
    public var isLoadingMore: Bool { state.isLoadingMore }
    public var totalMessageCount: Int { state.totalMessageCount }

    public func configure(conversationVM: LumiCoreKit.WindowConversationVM) {
        guard self.conversationVM !== conversationVM else { return }

        self.conversationVM = conversationVM
        state.selectedConversationId = conversationVM.selectedConversationId
        cancellables.removeAll()
        setupBindings(conversationVM: conversationVM)
        handleOnAppear()
    }

    public func handleOnAppear() {
        Task { await loadMessagesForSelection() }
    }

    public func handleConversationChanged() {
        guard let conversationVM else { return }
        Task { await didSelectConversation(conversationVM.selectedConversationId) }
    }

    public func handleMessageSaved(_ message: ChatMessage, conversationId: UUID) {
        guard conversationId == state.selectedConversationId else { return }
        objectWillChange.send()
        state.queuedMessages.removeAll { $0.id == message.id }
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

    public func handleMessageQueued(_ message: ChatMessage) {
        guard message.conversationId == state.selectedConversationId else { return }
        guard message.shouldDisplayInChatList() else { return }
        guard !state.persistedMessages.contains(where: { $0.id == message.id }) else { return }

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

    public func removeQueuedMessage(id messageId: UUID) {
        state.queuedMessages.removeAll { $0.id == messageId }
        refreshActiveStreamingMessage()
    }

    public func handleLoadMore() {
        guard state.hasMoreMessages,
              !state.isLoadingMore,
              let conversationId = state.selectedConversationId,
              let conversationVM
        else { return }

        Task { @MainActor in
            state.isLoadingMore = true
            defer { state.isLoadingMore = false }

            let result = await conversationVM.loadMessagesPage(
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

    public func deleteMessage(_ messageId: UUID) {
        guard let conversationId = state.selectedConversationId,
              let conversationVM
        else { return }

        Task { @MainActor in
            let deleted = await conversationVM.deleteMessages(
                messageIds: [messageId],
                conversationId: conversationId
            )
            guard deleted > 0 else { return }

            state.persistedMessages.removeAll { $0.id == messageId }
            state.totalMessageCount = max(0, state.totalMessageCount - 1)
        }
    }

    public func handleUserDidSendMessage() {
        // User sent a message; ViewModel state update handled by saved-message events.
    }

    private func setupBindings(conversationVM: LumiCoreKit.WindowConversationVM) {
        conversationVM.$selectedConversationId
            .removeDuplicates()
            .sink { [weak self] conversationId in
                guard let self else { return }
                Task { @MainActor in
                    await self.didSelectConversation(conversationId)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("messageSaved"))
            .sink { [weak self] notification in
                guard let self,
                      let message = notification.object as? ChatMessage,
                      let conversationId = notification.userInfo?["conversationId"] as? UUID
                else { return }

                self.handleMessageSaved(message, conversationId: conversationId)
            }
            .store(in: &cancellables)

        conversationVM.$statusVersion
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func didSelectConversation(_ conversationId: UUID?) async {
        state.selectedConversationId = conversationId
        await loadMessagesForSelection()
    }

    private func loadMessagesForSelection() async {
        guard let conversationId = state.selectedConversationId,
              let conversationVM
        else {
            state.persistedMessages = []
            state.queuedMessages = []
            state.activeStreamingMessage = nil
            state.hasMoreMessages = false
            state.totalMessageCount = 0
            state.oldestLoadedTimestamp = nil
            return
        }

        state.isLoadingMore = true
        defer { state.isLoadingMore = false }

        let count = await conversationVM.getMessageCount(forConversationId: conversationId)
        state.totalMessageCount = count

        let result = await conversationVM.loadMessagesPage(
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

        if let conversationId = state.selectedConversationId,
           let statusMessage = conversationVM?.statusMessage(for: conversationId) {
            rows.append(statusMessage)
        }

        return rows
    }

    private func refreshActiveStreamingMessage() {
        state.activeStreamingMessage = nil
    }
}
