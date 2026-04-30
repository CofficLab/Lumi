import AppKit
import MagicKit
import SwiftUI

/// 消息列表视图组件
struct MessageListView: View {
    nonisolated static let defaultHistoryWindowLimit = 80
    nonisolated static let historyWindowStep = 40

    @EnvironmentObject var timelineViewModel: ChatTimelineViewModel
    @EnvironmentObject var conversationSendStatusVM: ConversationStatusVM

    private let bottomAnchorId = "chat_message_list_bottom_anchor"
    @State private var historyWindowLimit = Self.defaultHistoryWindowLimit
    @State private var shouldPinLatestUserMessageToTop = false
    @State private var keepLatestUserMessageAtTop = false
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var followNewMessages = true
    @State private var isProgrammaticScrolling = false
    @State private var forceScrollToBottomOnNextChange = false
    private struct DisplayRow: Identifiable {
        let id: UUID
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]
    }

    var body: some View {
        ScrollViewReader { proxy in
            let windowedPersistedRows = windowedHistoryRows(from: timelineViewModel.persistedMessages)
            let hiddenLoadedHistoryCount = max(0, timelineViewModel.persistedMessages.count - windowedPersistedRows.count)
            let displayRows = buildDisplayRows(from: windowedPersistedRows, statusRow: statusDisplayRow)
            let lastMessageID = displayRows.last?.id
            let lastRowChangeToken = lastRowChangeToken(for: displayRows)
            let focusSpacerHeight = keepLatestUserMessageAtTop ? max(scrollViewportHeight * 0.95, 500) : 0

            Group {
                if displayRows.isEmpty {
                    if timelineViewModel.isLoadingMore, timelineViewModel.selectedConversationId != nil {
                        loadingOverlay
                    } else {
                        EmptyMessagesView()
                    }
                } else {
                    messageScrollView(
                        displayRows: displayRows,
                        lastMessageID: lastMessageID,
                        hiddenLoadedHistoryCount: hiddenLoadedHistoryCount,
                        focusSpacerHeight: focusSpacerHeight
                    )
                }
            }
            .onAppear {
                historyWindowLimit = Self.defaultHistoryWindowLimit
                shouldPinLatestUserMessageToTop = false
                keepLatestUserMessageAtTop = false
                setFollowNewMessages(true)
                timelineViewModel.handleOnAppear()
                DispatchQueue.main.async {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: timelineViewModel.selectedConversationId) { _, _ in
                historyWindowLimit = Self.defaultHistoryWindowLimit
                shouldPinLatestUserMessageToTop = false
                keepLatestUserMessageAtTop = false
                forceScrollToBottomOnNextChange = false
                setFollowNewMessages(true)
            }
            .onChange(of: lastRowChangeToken) { _, _ in
                handleLastMessageChanged(proxy: proxy)
            }
            .onMessageSaved { message, conversationId in
                timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
                guard conversationId == timelineViewModel.selectedConversationId else { return }
                guard message.role == .user, message.shouldDisplayInChatList() else { return }

                forceScrollToBottomOnNextChange = true
                shouldPinLatestUserMessageToTop = false
                keepLatestUserMessageAtTop = false
                setFollowNewMessages(true)

                DispatchQueue.main.async {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
            .onAgentInputDidSendMessage {
                handleUserDidSendMessageEvent(proxy: proxy)
            }
        }
    }
}

// MARK: - View

extension MessageListView {
    private func messageScrollView(
        displayRows: [DisplayRow],
        lastMessageID: UUID?,
        hiddenLoadedHistoryCount: Int,
        focusSpacerHeight: CGFloat
    ) -> some View {
        return List {
            if hiddenLoadedHistoryCount > 0 {
                showEarlierLoadedButton(hiddenCount: hiddenLoadedHistoryCount)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
            }

            if timelineViewModel.hasMoreMessages {
                loadMoreButton
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
            }

            ForEach(displayRows) { row in
                ChatBubble(
                    message: row.message,
                    isLastMessage: row.id == lastMessageID,
                    relatedToolOutputs: row.relatedToolOutputs,
                    isStreaming: false
                )
                .id(row.id)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
            }

            Color.clear
                .frame(height: 1)
                .id(bottomAnchorId)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

            if focusSpacerHeight > 0 {
                Color.clear
                    .frame(height: focusSpacerHeight)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.preferOuterScroll, true)
        .accessibilityLabel(String(localized: "Message List", table: "AgentChat"))
        .accessibilityHint(String(localized: "Message List Hint", table: "AgentChat"))
        .overlay(alignment: .topLeading) {
            ScrollPositionObserver { atBottom, userInitiated in
                handleScrollPositionChanged(atBottom: atBottom, userInitiated: userInitiated)
            }
            .frame(width: 0, height: 0)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        scrollViewportHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        scrollViewportHeight = newHeight
                    }
            }
        )
    }

    private func showEarlierLoadedButton(hiddenCount: Int) -> some View {
        HStack {
            Spacer()
            AppButton(
                String(
                    format: String(localized: "Expand Earlier Loaded Messages (%lld)", table: "AgentChat"),
                    hiddenCount
                ),
                systemImage: "clock.arrow.circlepath",
                style: .tonal,
                size: .small
            ) {
                historyWindowLimit += Self.historyWindowStep
            }
            .accessibilityLabel(String(localized: "Expand Earlier Messages", table: "AgentChat"))
            .accessibilityHint(String(localized: "Expand Earlier Messages Hint", table: "AgentChat"))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(String(localized: "Loading History", table: "AgentChat"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadMoreButton: some View {
        HStack {
            Spacer()
            if timelineViewModel.isLoadingMore {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(loadMoreButtonText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: AppUI.Radius.sm, style: .continuous)
                        .fill(AppUI.Color.semantic.textSecondary.opacity(0.08))
                )
                .accessibilityLabel(String(localized: "Load Earlier Messages", table: "AgentChat"))
                .accessibilityHint(String(localized: "Load Earlier Messages Hint", table: "AgentChat"))
            } else {
                AppButton(
                    loadMoreButtonText,
                    systemImage: "arrow.up.circle",
                    style: .tonal,
                    size: .small
                ) {
                    timelineViewModel.handleLoadMore()
                }
                .accessibilityLabel(String(localized: "Load Earlier Messages", table: "AgentChat"))
                .accessibilityHint(String(localized: "Load Earlier Messages Hint", table: "AgentChat"))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var loadMoreButtonText: String {
        if timelineViewModel.isLoadingMore {
            return String(localized: "Loading More Messages", table: "AgentChat")
        }
        let loadedCount = timelineViewModel.persistedMessages.count
        return String(
            format: String(localized: "Load More Messages (%lld of %lld)", table: "AgentChat"),
            loadedCount,
            timelineViewModel.totalMessageCount
        )
    }
}

// MARK: - Event Handlers

extension MessageListView {
    private func handleUserDidSendMessageEvent(proxy: ScrollViewProxy) {
        timelineViewModel.handleUserDidSendMessage()
        shouldPinLatestUserMessageToTop = false
        keepLatestUserMessageAtTop = false
        setFollowNewMessages(true)
        DispatchQueue.main.async {
            scrollToBottom(proxy: proxy, animated: true)
        }
    }

    private func handleLastMessageChanged(proxy: ScrollViewProxy) {
        guard !windowedHistoryRows(from: timelineViewModel.persistedMessages).isEmpty else { return }

        if forceScrollToBottomOnNextChange {
            forceScrollToBottomOnNextChange = false
            scrollToBottom(proxy: proxy, animated: false)
            return
        }

        if shouldPinLatestUserMessageToTop {
            scrollLatestUserMessageToTop(proxy: proxy, animated: false)
            shouldPinLatestUserMessageToTop = false
            keepLatestUserMessageAtTop = true
            setFollowNewMessages(false)
            return
        }

        if timelineViewModel.shouldPerformInitialScrollAfterMessageChange() {
            scrollToBottom(proxy: proxy, animated: false)
            return
        }

        if followNewMessages {
            scrollToBottom(proxy: proxy, animated: true)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        beginProgrammaticScrolling()
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(bottomAnchorId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorId, anchor: .bottom)
        }
    }

    private func scrollLatestUserMessageToTop(proxy: ScrollViewProxy, animated: Bool) {
        guard let latestUserMessageId = latestVisibleUserMessageId() else { return }
        beginProgrammaticScrolling()
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(latestUserMessageId, anchor: .top)
            }
        } else {
            proxy.scrollTo(latestUserMessageId, anchor: .top)
        }
    }

    private func latestVisibleUserMessageId() -> UUID? {
        windowedHistoryRows(from: timelineViewModel.persistedMessages)
            .last(where: { $0.role == .user })?
            .id
    }

    private func buildDisplayRows(from messages: [ChatMessage], statusRow: DisplayRow? = nil) -> [DisplayRow] {
        var rows = messages.map { message in
            DisplayRow(
                id: message.id,
                message: message,
                relatedToolOutputs: timelineViewModel.toolOutputs(for: message)
            )
        }
        if let statusRow = statusRow {
            rows.append(statusRow)
        }
        return rows
    }

    private func windowedHistoryRows(from messages: [ChatMessage]) -> [ChatMessage] {
        guard historyWindowLimit > 0 else { return [] }
        if messages.count <= historyWindowLimit {
            return messages
        }
        return Array(messages.suffix(historyWindowLimit))
    }

    private var statusDisplayRow: DisplayRow? {
        guard let sid = timelineViewModel.selectedConversationId,
              let vmMessage = conversationSendStatusVM.statusMessage(for: sid)
        else { return nil }
        return DisplayRow(id: vmMessage.id, message: vmMessage, relatedToolOutputs: [])
    }

    private func lastRowChangeToken(for rows: [DisplayRow]) -> Int {
        var hasher = Hasher()
        hasher.combine(rows.count)
        if let last = rows.last {
            hasher.combine(last.id)
            hasher.combine(last.message.timestamp.timeIntervalSinceReferenceDate)
            hasher.combine(last.message.content)
        }
        return hasher.finalize()
    }

    private func handleScrollPositionChanged(atBottom: Bool, userInitiated: Bool) {
        if userInitiated && !isProgrammaticScrolling && !atBottom {
            setFollowNewMessages(false)
            return
        }

        // 只有用户主动滚到最底部时，才恢复自动跟随，避免内容更新误判导致“抢滚动条”。
        if userInitiated && atBottom {
            setFollowNewMessages(true)
            keepLatestUserMessageAtTop = false
        }
    }

    private func setFollowNewMessages(_ follow: Bool) {
        guard followNewMessages != follow else { return }
        followNewMessages = follow
        if follow {
            timelineViewModel.enableAutoFollow()
        } else {
            timelineViewModel.disableAutoFollow()
        }
    }

    private func beginProgrammaticScrolling() {
        isProgrammaticScrolling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isProgrammaticScrolling = false
        }
    }
}

private struct ScrollPositionObserver: NSViewRepresentable {
    let onMetricsChanged: (_ atBottom: Bool, _ userInitiated: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMetricsChanged: onMetricsChanged)
    }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        context.coordinator.onMetricsChanged = onMetricsChanged
        context.coordinator.attachIfNeeded(from: nsView)
    }

    final class ProbeView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attachIfNeeded(from: self)
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            coordinator?.attachIfNeeded(from: self)
        }
    }

    final class Coordinator {
        private static let bottomEpsilon: CGFloat = 6

        var onMetricsChanged: (_ atBottom: Bool, _ userInitiated: Bool) -> Void

        private weak var scrollView: NSScrollView?
        private weak var documentView: NSView?
        private var observers: [NSObjectProtocol] = []
        private var isLiveScrolling = false

        init(onMetricsChanged: @escaping (_ atBottom: Bool, _ userInitiated: Bool) -> Void) {
            self.onMetricsChanged = onMetricsChanged
        }

        deinit {
            removeObservers()
        }

        func attachIfNeeded(from probe: NSView) {
            guard let enclosing = findEnclosingScrollView(from: probe) else { return }
            guard scrollView !== enclosing else {
                emitMetrics(userInitiated: false)
                return
            }

            removeObservers()
            scrollView = enclosing
            bindObservers(to: enclosing)
            emitMetrics(userInitiated: false)
        }

        private func findEnclosingScrollView(from view: NSView) -> NSScrollView? {
            var node: NSView? = view
            while let current = node {
                if let sv = current as? NSScrollView {
                    return sv
                }
                node = current.superview
            }

            // 对于 SwiftUI 的 overlay 场景，探针可能不在 NSScrollView 子树内。
            // 退化为从祖先节点向下查找最近的 NSScrollView。
            var ancestor: NSView? = view.superview
            while let current = ancestor {
                if let found = findFirstScrollView(in: current) {
                    return found
                }
                ancestor = current.superview
            }
            return nil
        }

        private func findFirstScrollView(in root: NSView) -> NSScrollView? {
            if let sv = root as? NSScrollView {
                return sv
            }
            for child in root.subviews {
                if let found = findFirstScrollView(in: child) {
                    return found
                }
            }
            return nil
        }

        private func bindObservers(to scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            let boundsObs = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.emitMetrics(userInitiated: self.isLikelyUserScroll())
            }
            observers.append(boundsObs)

            let startObs = NotificationCenter.default.addObserver(
                forName: NSScrollView.willStartLiveScrollNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                self?.isLiveScrolling = true
            }
            observers.append(startObs)

            let endObs = NotificationCenter.default.addObserver(
                forName: NSScrollView.didEndLiveScrollNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.isLiveScrolling = false
                self.emitMetrics(userInitiated: true)
            }
            observers.append(endObs)

            if let doc = scrollView.documentView {
                doc.postsFrameChangedNotifications = true
                documentView = doc
                let frameObs = NotificationCenter.default.addObserver(
                    forName: NSView.frameDidChangeNotification,
                    object: doc,
                    queue: .main
                ) { [weak self] _ in
                    self?.emitMetrics(userInitiated: false)
                }
                observers.append(frameObs)
            }
        }

        private func isLikelyUserScroll() -> Bool {
            guard isLiveScrolling || NSApp.currentEvent != nil else { return false }
            if isLiveScrolling {
                return true
            }
            guard let type = NSApp.currentEvent?.type else { return false }
            switch type {
            case .scrollWheel, .leftMouseDragged, .leftMouseDown, .otherMouseDragged:
                return true
            default:
                return false
            }
        }

        private func emitMetrics(userInitiated: Bool) {
            guard let scrollView,
                  let documentView = scrollView.documentView else { return }
            let clip = scrollView.contentView
            let visibleBottom = clip.bounds.maxY
            let contentHeight = documentView.bounds.height
            let distanceToBottom = contentHeight - visibleBottom
            let atBottom = distanceToBottom <= Self.bottomEpsilon
            onMetricsChanged(atBottom, userInitiated)
        }

        private func removeObservers() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            documentView?.postsFrameChangedNotifications = false
            scrollView?.contentView.postsBoundsChangedNotifications = false
            documentView = nil
            scrollView = nil
            isLiveScrolling = false
        }
    }
}

// MARK: - Preview

#Preview("MessageListView - Small") {
    RootView { MessageListView() }
        .padding()
        .background(Color.black)
        .frame(width: 800, height: 600)
}

#Preview("MessageListView - Large") {
    RootView { MessageListView() }
        .padding()
        .background(Color.black)
        .frame(width: 1200, height: 1200)
}
