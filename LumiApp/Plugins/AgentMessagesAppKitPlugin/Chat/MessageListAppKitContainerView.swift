import AppKit
import Combine
import OSLog
import SwiftUI
import MagicKit

private struct AppKitMessageListContentView: View {
    let messages: [ChatMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(messages, id: \.id) { message in
                AppKitMessageRowView(message: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

final class MessageListAppKitContainerView: NSView {
    private var agentProvider: AgentProvider
    private var conversationViewModel: ConversationViewModel
    private var processingStateViewModel: ProcessingStateViewModel

    private let scrollView = NSScrollView()
    private let hostingView = NSHostingView(rootView: AppKitMessageListContentView(messages: []))

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

        hostingView.rootView = AppKitMessageListContentView(messages: messages)
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

