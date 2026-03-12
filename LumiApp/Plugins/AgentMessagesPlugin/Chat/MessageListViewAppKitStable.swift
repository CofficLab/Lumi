import AppKit
import MagicKit
import OSLog
import SwiftUI

/// 消息列表视图组件（稳定版：外层 AppKit NSScrollView，内部 SwiftUI 气泡）
/// 该文件用于备份已验证“不再卡死”的实现；后续实验请改 MessageListViewAppKitExperimental。
struct MessageListViewAppKitStable: View, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = true
    nonisolated static let pageSize: Int = 50

    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var conversationViewModel: ConversationViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateViewModel

    @State private var messages: [ChatMessage] = []
    @State private var transientStatusMessageId: UUID = UUID()
    @State private var hasMoreMessages: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var totalMessageCount: Int = 0
    @State private var oldestLoadedTimestamp: Date?

    private var selectedConversationId: UUID? {
        conversationViewModel.selectedConversationId
    }

    private var nonSystemMessages: [ChatMessage] {
        messages.filter { $0.role.shouldDisplayInChatList }
    }

    private var displayItems: [MessageListView.DisplayMessageItem] {
        var items: [MessageListView.DisplayMessageItem] = []
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
                items.append(MessageListView.DisplayMessageItem(message: message, relatedToolOutputs: groupedOutputs))
                index = cursor
                continue
            }
            items.append(MessageListView.DisplayMessageItem(message: message, relatedToolOutputs: []))
            index += 1
        }
        return items
    }

    var body: some View {
        let items = displayItems
        let lastMessageID = items.last?.id

        MessageListViewAppKitStableRepresentable(
            items: items,
            lastMessageID: lastMessageID,
            agentProvider: agentProvider,
            processingStateViewModel: processingStateViewModel,
            hasMoreMessages: hasMoreMessages,
            isLoadingMore: isLoadingMore,
            loadMoreButtonText: loadMoreButtonText,
            onLoadMore: handleLoadMore
        )
        .onAppear { Task { await loadMessages() } }
        .onChange(of: selectedConversationId, handleConversationChanged)
        .onChange(of: processingStateViewModel.isProcessing, applyTransientStatusMessageIfNeeded)
        .onChange(of: processingStateViewModel.statusText, applyTransientStatusMessageIfNeeded)
        .onMessageSaved(perform: handleOnMessageSaved)
    }

    private var loadMoreButtonText: String {
        if isLoadingMore { return "加载中..." }
        return "加载更早消息（已加载 \(messages.count) 条，共 \(totalMessageCount) 条）"
    }

    private func applyTransientStatusMessageIfNeeded() {
        guard selectedConversationId != nil else { return }
        if processingStateViewModel.isProcessing, !processingStateViewModel.statusText.isEmpty {
            let statusText = processingStateViewModel.statusText
            if let index = messages.firstIndex(where: { $0.id == transientStatusMessageId }) {
                var m = messages[index]
                m.content = statusText
                var updated = messages
                updated[index] = m
                messages = updated
            } else {
                let m = ChatMessage(
                    id: transientStatusMessageId,
                    role: .status,
                    content: statusText,
                    timestamp: Date(),
                    isTransientStatus: true
                )
                messages.append(m)
            }
        } else {
            if messages.contains(where: { $0.id == transientStatusMessageId }) {
                messages.removeAll { $0.id == transientStatusMessageId }
            }
        }
    }

    private func loadMessages() async {
        guard let conversationId = selectedConversationId else { return }
        await MainActor.run { isLoadingMore = true }
        defer { Task { @MainActor in isLoadingMore = false } }
        let count = await agentProvider.getMessageCount(forConversationId: conversationId)
        await MainActor.run { totalMessageCount = count }
        let result = await agentProvider.loadMessagesPage(
            forConversationId: conversationId,
            limit: Self.pageSize,
            beforeTimestamp: nil
        )
        await MainActor.run {
            messages = result.messages
            hasMoreMessages = result.hasMore
            if let first = result.messages.first { oldestLoadedTimestamp = first.timestamp }
            applyTransientStatusMessageIfNeeded()
        }
    }

    private func handleLoadMore() {
        guard hasMoreMessages, !isLoadingMore, let conversationId = selectedConversationId else { return }
        Task { @MainActor in
            isLoadingMore = true
            defer { isLoadingMore = false }
            let result = await agentProvider.loadMessagesPage(
                forConversationId: conversationId,
                limit: Self.pageSize,
                beforeTimestamp: oldestLoadedTimestamp
            )
            messages.insert(contentsOf: result.messages, at: 0)
            hasMoreMessages = result.hasMore
            if let first = result.messages.first { oldestLoadedTimestamp = first.timestamp }
        }
    }

    private func handleConversationChanged() {
        Task {
            await MainActor.run { transientStatusMessageId = UUID() }
            await loadMessages()
        }
    }

    private func handleOnMessageSaved(message: ChatMessage, conversationId: UUID) {
        guard conversationId == selectedConversationId else { return }
        Task { @MainActor in
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                messages[idx] = message
            } else {
                if let insertIndex = messages.firstIndex(where: { $0.timestamp > message.timestamp }) {
                    messages.insert(message, at: insertIndex)
                } else {
                    messages.append(message)
                }
            }
            totalMessageCount = max(totalMessageCount, messages.count)
            if let first = messages.first { oldestLoadedTimestamp = first.timestamp }
        }
    }
}

private struct MessageListViewAppKitStableRepresentable: NSViewRepresentable {
    let items: [MessageListView.DisplayMessageItem]
    let lastMessageID: UUID?
    let agentProvider: AgentProvider
    let processingStateViewModel: ProcessingStateViewModel
    let hasMoreMessages: Bool
    let isLoadingMore: Bool
    let loadMoreButtonText: String
    let onLoadMore: () -> Void

    func makeNSView(context: Context) -> MessageListViewAppKitStableContainerView {
        let view = MessageListViewAppKitStableContainerView(frame: .zero)
        view.updateContent(
            items: items,
            lastMessageID: lastMessageID,
            agentProvider: agentProvider,
            processingStateViewModel: processingStateViewModel,
            hasMoreMessages: hasMoreMessages,
            isLoadingMore: isLoadingMore,
            loadMoreButtonText: loadMoreButtonText,
            onLoadMore: onLoadMore
        )
        return view
    }

    func updateNSView(_ nsView: MessageListViewAppKitStableContainerView, context: Context) {
        nsView.updateContent(
            items: items,
            lastMessageID: lastMessageID,
            agentProvider: agentProvider,
            processingStateViewModel: processingStateViewModel,
            hasMoreMessages: hasMoreMessages,
            isLoadingMore: isLoadingMore,
            loadMoreButtonText: loadMoreButtonText,
            onLoadMore: onLoadMore
        )
    }
}

private struct MessageListViewAppKitStableContentView: View {
    let items: [MessageListView.DisplayMessageItem]
    let lastMessageID: UUID?
    let agentProvider: AgentProvider
    let processingStateViewModel: ProcessingStateViewModel
    let hasMoreMessages: Bool
    let isLoadingMore: Bool
    let loadMoreButtonText: String
    let onLoadMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasMoreMessages {
                HStack {
                    Spacer()
                    Button(action: onLoadMore) {
                        HStack(spacing: 8) {
                            if isLoadingMore {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.circle")
                            }
                            Text(loadMoreButtonText).font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingMore)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            ForEach(items) { item in
                ChatBubble(
                    message: item.message,
                    isLastMessage: item.id == lastMessageID,
                    relatedToolOutputs: item.relatedToolOutputs
                )
                .environmentObject(agentProvider)
                .environmentObject(agentProvider.thinkingStateViewModel)
                .environmentObject(processingStateViewModel)
            }
        }
        .padding(.horizontal)
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private final class MessageListViewAppKitStableContainerView: NSView {
    private let scrollView = NSScrollView()
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUpViews()
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

    func updateContent(
        items: [MessageListView.DisplayMessageItem],
        lastMessageID: UUID?,
        agentProvider: AgentProvider,
        processingStateViewModel: ProcessingStateViewModel,
        hasMoreMessages: Bool,
        isLoadingMore: Bool,
        loadMoreButtonText: String,
        onLoadMore: @escaping () -> Void
    ) {
        let clipView = scrollView.contentView
        let previousOrigin = clipView.bounds.origin
        let shouldStickToBottom = isNearBottom()

        hostingView.rootView = AnyView(
            MessageListViewAppKitStableContentView(
                items: items,
                lastMessageID: lastMessageID,
                agentProvider: agentProvider,
                processingStateViewModel: processingStateViewModel,
                hasMoreMessages: hasMoreMessages,
                isLoadingMore: isLoadingMore,
                loadMoreButtonText: loadMoreButtonText,
                onLoadMore: onLoadMore
            )
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

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutDocumentView()
            if shouldStickToBottom {
                self.scrollToBottom()
            } else {
                let cv = self.scrollView.contentView
                let maxY = max(0, self.hostingView.frame.height - cv.bounds.height)
                let targetY = min(previousOrigin.y, maxY)
                cv.scroll(to: NSPoint(x: previousOrigin.x, y: targetY))
                self.scrollView.reflectScrolledClipView(cv)
            }
        }
    }

    private func setUpViews() {
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

    private func layoutDocumentView() {
        let targetWidth = max(0, scrollView.contentView.bounds.width)
        let currentHeight = max(1, hostingView.frame.height)
        hostingView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: currentHeight)
        hostingView.layoutSubtreeIfNeeded()
        let fitting = hostingView.fittingSize
        let extraBottomPadding: CGFloat = 64
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: targetWidth,
            height: max(1, fitting.height + extraBottomPadding)
        )
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

