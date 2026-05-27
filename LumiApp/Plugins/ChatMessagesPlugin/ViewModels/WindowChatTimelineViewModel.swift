import Combine
import AgentToolKit
import Foundation

@MainActor
final class WindowChatTimelineViewModel: ObservableObject {
    nonisolated static let pageSize: Int = 10

    @Published private(set) var state = ConversationRenderState()

    private let chatHistoryService: ChatHistoryService
    private let conversationVM: WindowConversationVM
    private let conversationSendStatusVM: WindowConversationStatusVM
    private var cancellables = Set<AnyCancellable>()

    init(
        chatHistoryService: ChatHistoryService,
        conversationVM: WindowConversationVM,
        conversationSendStatusVM: WindowConversationStatusVM
    ) {
        self.chatHistoryService = chatHistoryService
        self.conversationVM = conversationVM
        self.conversationSendStatusVM = conversationSendStatusVM
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
        // User sent a message; ViewModel state update handled by callers.
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

        // 状态消息变化时触发 UI 刷新（status 行内容由 conversationSendStatusVM 驱动）
        conversationSendStatusVM.$statusMessageByConversationId
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
        guard let conversationId = state.selectedConversationId else {
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

        // 内核自动注入当前会话的状态消息（如发送/流式/工具执行状态）
        if let conversationId = state.selectedConversationId,
           let statusMessage = conversationSendStatusVM.statusMessage(for: conversationId) {
            rows.append(statusMessage)
        }

        return rows
    }


    private func refreshActiveStreamingMessage() {
        state.activeStreamingMessage = nil
    }
}
