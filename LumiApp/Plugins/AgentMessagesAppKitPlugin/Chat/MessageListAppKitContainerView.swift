import AppKit
import Combine
import OSLog
import SwiftUI
import MagicKit

private struct AppKitMessageListContentView: View {
    let messages: [ChatMessage]
    let agentProvider: AgentProvider
    let processingStateViewModel: ProcessingStateViewModel
    let thinkingStateViewModel: ThinkingStateViewModel

    private struct DisplayMessageItem: Identifiable {
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]
        var id: UUID { message.id }
    }

    private var nonSystemMessages: [ChatMessage] {
        messages.filter { $0.role.shouldDisplayInChatList }
    }

    private var displayItems: [DisplayMessageItem] {
        var items: [DisplayMessageItem] = []
        var index = 0

        while index < nonSystemMessages.count {
            let message = nonSystemMessages[index]

            if message.role == .assistant,
               let toolCalls = message.toolCalls,
               !toolCalls.isEmpty {
                let toolCallIDs = Set(toolCalls.map(\.id))
                var groupedOutputs: [ChatMessage] = []
                var cursor = index + 1

                while cursor < nonSystemMessages.count {
                    let next = nonSystemMessages[cursor]
                    guard let toolCallID = next.toolCallID else { break }
                    guard toolCallIDs.contains(toolCallID) else { break }
                    groupedOutputs.append(next)
                    cursor += 1
                }

                items.append(DisplayMessageItem(message: message, relatedToolOutputs: groupedOutputs))
                index = cursor
                continue
            }

            items.append(DisplayMessageItem(message: message, relatedToolOutputs: []))
            index += 1
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let items = displayItems
            let lastMessageId = items.last?.id

            ForEach(items) { item in
                AppKitChatBubble(
                    message: item.message,
                    isLastMessage: item.id == lastMessageId,
                    relatedToolOutputs: item.relatedToolOutputs
                )
                .environmentObject(agentProvider)
                .environmentObject(processingStateViewModel)
                .environmentObject(thinkingStateViewModel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 根视图：注入 preferOuterScroll，避免长 MD 消息内部滚动“吸住”滚轮
private struct AppKitMessageListRootView: View {
    let messages: [ChatMessage]
    let agentProvider: AgentProvider
    let processingStateViewModel: ProcessingStateViewModel
    let thinkingStateViewModel: ThinkingStateViewModel

    var body: some View {
        AppKitMessageListContentView(
            messages: messages,
            agentProvider: agentProvider,
            processingStateViewModel: processingStateViewModel,
            thinkingStateViewModel: thinkingStateViewModel
        )
        .environment(\.preferOuterScroll, true)
    }
}

final class MessageListAppKitContainerView: NSView {
    private var agentProvider: AgentProvider
    private var conversationViewModel: ConversationViewModel
    private var processingStateViewModel: ProcessingStateViewModel

    private let scrollView = NSScrollView()
    private let hostingView: NSHostingView<AppKitMessageListRootView>

    private var messages: [ChatMessage] = [] {
        didSet { rebuildMessageViews() }
    }

    private static let pageSize: Int = 50

    private var totalMessageCount: Int = 0
    private var oldestLoadedTimestamp: Date?
    private var isLoadingMore: Bool = false
    private var currentConversationId: UUID?
    private var transientStatusMessageId: UUID = UUID()
    private var processingCancellables = Set<AnyCancellable>()

    init(
        agentProvider: AgentProvider,
        conversationViewModel: ConversationViewModel,
        processingStateViewModel: ProcessingStateViewModel
    ) {
        self.agentProvider = agentProvider
        self.conversationViewModel = conversationViewModel
        self.processingStateViewModel = processingStateViewModel
        self.hostingView = NSHostingView(
            rootView: AppKitMessageListRootView(
                messages: [],
                agentProvider: agentProvider,
                processingStateViewModel: processingStateViewModel,
                thinkingStateViewModel: agentProvider.thinkingStateViewModel
            )
        )
        super.init(frame: .zero)

        setUpViews()
        setUpObservers()
        bindProcessingState()
        currentConversationId = conversationViewModel.selectedConversationId
        Task { [weak self] in
            await self?.loadInitialMessages()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .messageSaved, object: nil)
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        layoutDocumentView()
    }

    func updateDependencies(
        agentProvider: AgentProvider,
        conversationViewModel: ConversationViewModel,
        processingStateViewModel: ProcessingStateViewModel
    ) {
        self.agentProvider = agentProvider
        self.conversationViewModel = conversationViewModel
        self.processingStateViewModel = processingStateViewModel

        let selectedId = conversationViewModel.selectedConversationId
        guard selectedId != currentConversationId else { return }
        currentConversationId = selectedId
        transientStatusMessageId = UUID()

        Task { [weak self] in
            await self?.loadInitialMessages()
        }
    }

    // MARK: - Private

    private func setUpViews() {
        wantsLayer = true

        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = hostingView
        scrollView.hasHorizontalScroller = false

        addSubview(scrollView)

        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
    }

    private func rebuildMessageViews() {
        let clipView = scrollView.contentView
        let previousOrigin = clipView.bounds.origin
        let shouldStickToBottom = isNearBottom()

        hostingView.rootView = AppKitMessageListRootView(
            messages: messages,
            agentProvider: agentProvider,
            processingStateViewModel: processingStateViewModel,
            thinkingStateViewModel: agentProvider.thinkingStateViewModel
        )
        layoutDocumentView()

        if shouldStickToBottom {
            scrollToBottom()
        } else {
            let maxY = max(0, hostingView.frame.height - clipView.bounds.height)
            let targetY = min(previousOrigin.y, maxY)
            clipView.scroll(to: NSPoint(x: previousOrigin.x, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    private func setUpObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMessageSaved(_:)),
            name: .messageSaved,
            object: nil
        )

        // 监听选中会话变化：解决启动时 selectedConversationId 晚于容器 init 恢复导致的空白列表
        conversationViewModel.$selectedConversationId
            .receive(on: RunLoop.main)
            .sink { [weak self] newId in
                guard let self else { return }
                guard newId != self.currentConversationId else { return }
                self.currentConversationId = newId
                self.transientStatusMessageId = UUID()
                if newId != nil {
                    Task { [weak self] in
                        await self?.loadInitialMessages()
                    }
                } else {
                    self.messages = []
                }
            }
            .store(in: &processingCancellables)
    }

    private func bindProcessingState() {
        processingCancellables.removeAll()

        processingStateViewModel.$isProcessing
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyTransientStatusMessageIfNeeded()
            }
            .store(in: &processingCancellables)

        processingStateViewModel.$statusText
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyTransientStatusMessageIfNeeded()
            }
            .store(in: &processingCancellables)
    }

    private func upsertMessage(_ message: ChatMessage) {
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx] = message
            return
        }
        if let insertIndex = messages.firstIndex(where: { $0.timestamp > message.timestamp }) {
            messages.insert(message, at: insertIndex)
        } else {
            messages.append(message)
        }
    }

    @objc
    private func handleMessageSaved(_ notification: Notification) {
        guard let message = notification.object as? ChatMessage,
              let conversationId = notification.userInfo?["conversationId"] as? UUID,
              conversationId == currentConversationId else {
            return
        }
        upsertMessage(message)
    }

    private func applyTransientStatusMessageIfNeeded() {
        guard currentConversationId != nil else { return }

        if processingStateViewModel.isProcessing, !processingStateViewModel.statusText.isEmpty {
            let statusText = processingStateViewModel.statusText
            if let index = messages.firstIndex(where: { $0.id == transientStatusMessageId }) {
                var statusMessage = messages[index]
                statusMessage.content = statusText
                messages[index] = statusMessage
            } else {
                let statusMessage = ChatMessage(
                    id: transientStatusMessageId,
                    role: .status,
                    content: statusText,
                    timestamp: Date(),
                    isTransientStatus: true
                )
                messages.append(statusMessage)
            }
        } else if messages.contains(where: { $0.id == transientStatusMessageId }) {
            messages.removeAll { $0.id == transientStatusMessageId }
        }
    }

    private func layoutDocumentView() {
        let targetWidth = max(0, scrollView.contentView.bounds.width)
        let currentHeight = max(1, hostingView.frame.height)
        hostingView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: currentHeight)
        hostingView.layoutSubtreeIfNeeded()
        let fitting = hostingView.fittingSize
        hostingView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: max(1, fitting.height))
    }

    private func loadInitialMessages() async {
        guard let conversationId = conversationViewModel.selectedConversationId else { return }

        await MainActor.run {
            isLoadingMore = true
        }
        defer {
            Task { @MainActor in
                self.isLoadingMore = false
            }
        }

        let count = await agentProvider.getMessageCount(forConversationId: conversationId)

        await MainActor.run {
            totalMessageCount = count
        }

        var allMessages: [ChatMessage] = []
        var beforeTimestamp: Date? = nil
        var hasMore = true

        while hasMore {
            let page = await agentProvider.loadMessagesPage(
                forConversationId: conversationId,
                limit: Self.pageSize,
                beforeTimestamp: beforeTimestamp
            )

            if page.messages.isEmpty {
                break
            }

            if beforeTimestamp == nil {
                allMessages = page.messages
            } else {
                allMessages.insert(contentsOf: page.messages, at: 0)
            }

            hasMore = page.hasMore
            beforeTimestamp = page.messages.first?.timestamp
        }

        await MainActor.run {
            messages = allMessages.filter { $0.role.shouldDisplayInChatList }
            if let first = allMessages.first {
                oldestLoadedTimestamp = first.timestamp
            }
            applyTransientStatusMessageIfNeeded()
            scrollToBottom()
        }
    }

    private func scrollToBottom() {
        layoutSubtreeIfNeeded()
        layoutDocumentView()
        let clipView = scrollView.contentView
        let maxY = max(0, hostingView.frame.height - clipView.bounds.height)
        clipView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(clipView)
    }

    private func isNearBottom(threshold: CGFloat = 120) -> Bool {
        let clipView = scrollView.contentView
        let maxY = max(0, hostingView.frame.height - clipView.bounds.height)
        return (maxY - clipView.bounds.origin.y) < threshold
    }
}

