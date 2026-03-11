import AppKit
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
        Task { [weak self] in
            await self?.loadInitialMessages()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        hostingView.rootView = AppKitMessageListContentView(messages: messages)
        layoutDocumentView()
    }

    private func layoutDocumentView() {
        let targetWidth = max(0, scrollView.contentView.bounds.width)
        hostingView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: 1)
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
        }
    }
}

