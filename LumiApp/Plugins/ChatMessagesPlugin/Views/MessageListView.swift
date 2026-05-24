import LumiUI
import AppKit
import SwiftUI
import MarkdownKit

/// 消息列表视图组件
struct MessageListView: View {
    nonisolated static let defaultHistoryWindowLimit = 80
    nonisolated static let historyWindowStep = 40

    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject var timelineViewModel: WindowChatTimelineViewModel
    @EnvironmentObject var projectVM: WindowProjectVM

    private let bottomAnchorId = "chat_message_list_bottom_anchor"
    @State private var historyWindowLimit = Self.defaultHistoryWindowLimit
    @State private var followNewMessages = true
    @State private var suppressAutoScrollUntil = Date.distantPast
    @State private var listScrollView: NSScrollView?
    @State private var isProgrammaticScrolling = false
    @State private var forceScrollToBottomOnNextChange = false
    @State private var lastRowChangeScheduler = LastRowChangeScheduler()
    @State private var documentHeightBeforePrepend: CGFloat?
    private struct DisplayRow: Identifiable {
        let id: UUID
        let message: ChatMessage
    }

    private struct LastRowChangeToken: Equatable {
        let rowCount: Int
        let id: UUID?
        let timestamp: TimeInterval
        let contentLength: Int
        let contentTail: Unicode.Scalar?

        /// 同一行仅正文变长（如底部状态行刷新）；列表不展示助手流式逐字输出。
        func isSameRowContentUpdate(from previous: LastRowChangeToken) -> Bool {
            rowCount == previous.rowCount &&
                id == previous.id &&
                contentLength != previous.contentLength
        }

        /// 在顶部插入更早消息（加载更多 / 展开已加载历史）时，最后一行不变、行数增加。
        func isPrependUpdate(from previous: LastRowChangeToken) -> Bool {
            rowCount > previous.rowCount &&
                id == previous.id &&
                id != nil
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            let windowedPersistedRows = windowedHistoryRows(from: timelineViewModel.visibleMessages)
            let hiddenLoadedHistoryCount = max(0, timelineViewModel.persistedMessages.count - windowedPersistedRows.count)
            let displayRows = buildDisplayRows(from: windowedPersistedRows)
            let lastMessageID = displayRows.last?.id
            let lastRowChangeToken = lastRowChangeToken(for: displayRows)

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
                        hiddenLoadedHistoryCount: hiddenLoadedHistoryCount
                    )
                }
            }
            .onAppear {
                historyWindowLimit = Self.defaultHistoryWindowLimit
                suppressAutoScrollUntil = .distantPast
                setFollowNewMessages(true)
                timelineViewModel.handleOnAppear()
                DispatchQueue.main.async {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: timelineViewModel.selectedConversationId) { _, _ in
                lastRowChangeScheduler.cancel()
                historyWindowLimit = Self.defaultHistoryWindowLimit
                suppressAutoScrollUntil = .distantPast
                forceScrollToBottomOnNextChange = false
                setFollowNewMessages(true)
            }
            .onDisappear {
                lastRowChangeScheduler.cancel()
            }
            .onChange(of: lastRowChangeToken) { oldToken, newToken in
                lastRowChangeScheduler.schedule {
                    handleLastMessageChanged(
                        proxy: proxy,
                        isSameRowContentUpdate: newToken.isSameRowContentUpdate(from: oldToken),
                        isPrependUpdate: newToken.isPrependUpdate(from: oldToken)
                    )
                }
            }
            .onMessageSaved { message, conversationId in
                timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
                guard conversationId == timelineViewModel.selectedConversationId else { return }
                guard message.role == .user, message.shouldDisplayInChatList() else { return }

                forceScrollToBottomOnNextChange = true
                suppressAutoScrollUntil = .distantPast
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

@MainActor
private final class LastRowChangeScheduler: @unchecked Sendable {
    private var generation = 0

    func schedule(_ action: @escaping @MainActor @Sendable () -> Void) {
        generation += 1
        let scheduledGeneration = generation
        RunLoop.main.perform { [weak self] in
            Task { @MainActor in
                guard self?.generation == scheduledGeneration else { return }
                action()
            }
        }
    }

    func cancel() {
        generation += 1
    }
}

// MARK: - View

extension MessageListView {
    private func messageScrollView(
        displayRows: [DisplayRow],
        lastMessageID: UUID?,
        hiddenLoadedHistoryCount: Int
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
                    isStreaming: false
                )
                .id(row.id)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .appMessageInsertionTransition(preference: motionPreference)
            }

            Color.clear
                .frame(height: 1)
                .id(bottomAnchorId)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.preferOuterScroll, true)
        .animation(LumiMotion.enabled(LumiMotion.messageInsertion, preference: motionPreference), value: lastMessageID)
        .accessibilityLabel(String(localized: "Message List", table: "AgentChat"))
        .accessibilityHint(String(localized: "Message List Hint", table: "AgentChat"))
        .overlay(alignment: .topLeading) {
            ScrollPositionObserver(
                onMetricsChanged: { atBottom, userInitiated in
                    handleScrollPositionChanged(atBottom: atBottom, userInitiated: userInitiated)
                },
                onUserScrollActivity: noteUserScrollActivity,
                onScrollViewResolved: { scrollView in
                    listScrollView = scrollView
                }
            )
            .frame(width: 0, height: 0)
        }
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
                beginBrowsingOlderMessages()
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
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
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
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .appSurface(style: .subtle, cornerRadius: 8)
                .accessibilityLabel(String(localized: "Load Earlier Messages", table: "AgentChat"))
                .accessibilityHint(String(localized: "Load Earlier Messages Hint", table: "AgentChat"))
            } else {
                AppButton(
                    loadMoreButtonText,
                    systemImage: "arrow.up.circle",
                    style: .tonal,
                    size: .small
                ) {
                    beginBrowsingOlderMessages()
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
        suppressAutoScrollUntil = .distantPast
        setFollowNewMessages(true)
        DispatchQueue.main.async {
            scrollToBottom(proxy: proxy, animated: true)
        }
    }

    private func handleLastMessageChanged(
        proxy: ScrollViewProxy,
        isSameRowContentUpdate: Bool,
        isPrependUpdate: Bool
    ) {
        guard !windowedHistoryRows(from: timelineViewModel.visibleMessages).isEmpty else { return }

        if isPrependUpdate {
            compensateScrollPositionAfterPrepend()
            return
        }

        guard shouldPerformAutoScrollNow() else { return }

        if forceScrollToBottomOnNextChange {
            forceScrollToBottomOnNextChange = false
            scrollToBottom(proxy: proxy, animated: false)
            return
        }

        if timelineViewModel.shouldPerformInitialScrollAfterMessageChange() {
            scrollToBottom(proxy: proxy, animated: false)
            return
        }

        guard followNewMessages else { return }

        // 状态行随 SSE 高频刷新，但列表不展示助手流式正文；不应抢滚动条。
        if isSameRowContentUpdate {
            return
        }

        scrollToBottom(proxy: proxy, animated: true)
    }

    /// 用户主动查看更早消息：暂停跟到底，并记录插入前的文档高度以便补偿滚动位置。
    private func beginBrowsingOlderMessages() {
        documentHeightBeforePrepend = listScrollView?.documentView?.bounds.height
        suppressAutoScrollUntil = Date().addingTimeInterval(1)
        setFollowNewMessages(false)
    }

    private func compensateScrollPositionAfterPrepend() {
        defer { documentHeightBeforePrepend = nil }
        guard let scrollView = listScrollView,
              let documentView = scrollView.documentView,
              let oldHeight = documentHeightBeforePrepend else { return }

        documentView.layoutSubtreeIfNeeded()
        let delta = documentView.bounds.height - oldHeight
        guard delta > 0.5 else { return }

        let clipView = scrollView.contentView
        clipView.scroll(to: NSPoint(x: 0, y: clipView.bounds.origin.y + delta))
        scrollView.reflectScrolledClipView(clipView)
    }

    private func shouldPerformAutoScrollNow() -> Bool {
        !isProgrammaticScrolling && Date() >= suppressAutoScrollUntil
    }

    private func noteUserScrollActivity() {
        guard !isProgrammaticScrolling else { return }
        suppressAutoScrollUntil = Date().addingTimeInterval(0.45)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        beginProgrammaticScrolling()
        if !animated, let listScrollView {
            listScrollView.scrollToDocumentBottom()
            return
        }
        if animated {
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.scroll, preference: motionPreference)) {
                proxy.scrollTo(bottomAnchorId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorId, anchor: .bottom)
        }
    }

    private func buildDisplayRows(from messages: [ChatMessage]) -> [DisplayRow] {
        return messages.map { message in
            DisplayRow(
                id: message.id,
                message: message
            )
        }
    }

    private func windowedHistoryRows(from messages: [ChatMessage]) -> [ChatMessage] {
        guard historyWindowLimit > 0 else { return [] }
        if messages.count <= historyWindowLimit {
            return messages
        }
        return Array(messages.suffix(historyWindowLimit))
    }

    private func lastRowChangeToken(for rows: [DisplayRow]) -> LastRowChangeToken {
        guard let last = rows.last else {
            return LastRowChangeToken(
                rowCount: 0,
                id: nil,
                timestamp: 0,
                contentLength: 0,
                contentTail: nil
            )
        }

        return LastRowChangeToken(
            rowCount: rows.count,
            id: last.id,
            timestamp: last.message.timestamp.timeIntervalSinceReferenceDate,
            contentLength: last.message.content.utf8.count,
            contentTail: last.message.content.unicodeScalars.last
        )
    }

    private func handleScrollPositionChanged(atBottom: Bool, userInitiated: Bool) {
        if userInitiated && !isProgrammaticScrolling && !atBottom {
            setFollowNewMessages(false)
            return
        }

        // 只有用户主动滚到最底部时，才恢复自动跟随，避免内容更新误判导致“抢滚动条”。
        if userInitiated && atBottom {
            setFollowNewMessages(true)
            suppressAutoScrollUntil = .distantPast
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
    let onUserScrollActivity: () -> Void
    let onScrollViewResolved: (NSScrollView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onMetricsChanged: onMetricsChanged,
            onUserScrollActivity: onUserScrollActivity,
            onScrollViewResolved: onScrollViewResolved
        )
    }

    func makeNSView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {
        context.coordinator.onMetricsChanged = onMetricsChanged
        context.coordinator.onUserScrollActivity = onUserScrollActivity
        context.coordinator.onScrollViewResolved = onScrollViewResolved
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

    final class Coordinator: @unchecked Sendable {
        private static let bottomEpsilon: CGFloat = 28

        var onMetricsChanged: (_ atBottom: Bool, _ userInitiated: Bool) -> Void
        var onUserScrollActivity: () -> Void
        var onScrollViewResolved: (NSScrollView) -> Void

        private weak var scrollView: NSScrollView?
        private weak var documentView: NSView?
        private var observers: [NSObjectProtocol] = []
        private var isLiveScrolling = false
        private var lastAtBottom: Bool?
        private var lastUserInitiated: Bool?

        init(
            onMetricsChanged: @escaping (_ atBottom: Bool, _ userInitiated: Bool) -> Void,
            onUserScrollActivity: @escaping () -> Void,
            onScrollViewResolved: @escaping (NSScrollView) -> Void
        ) {
            self.onMetricsChanged = onMetricsChanged
            self.onUserScrollActivity = onUserScrollActivity
            self.onScrollViewResolved = onScrollViewResolved
        }

        deinit {
            MainActor.assumeIsolated {
                removeObservers()
            }
        }

        @MainActor
        func attachIfNeeded(from probe: NSView) {
            guard let enclosing = findEnclosingScrollView(from: probe) else { return }
            guard scrollView !== enclosing else {
                emitMetrics(userInitiated: false)
                return
            }

            removeObservers()
            scrollView = enclosing
            onScrollViewResolved(enclosing)
            bindObservers(to: enclosing)
            emitMetrics(userInitiated: false)
        }

        @MainActor
        private func findEnclosingScrollView(from view: NSView) -> NSScrollView? {
            var node: NSView? = view
            while let current = node {
                if let tableView = current as? NSTableView {
                    return tableView.enclosingScrollView
                }
                node = current.superview
            }

            if let tableView = findFirstTableView(in: view) {
                return tableView.enclosingScrollView
            }

            var ancestor: NSView? = view.superview
            while let current = ancestor {
                if let tableView = findFirstTableView(in: current) {
                    return tableView.enclosingScrollView
                }
                ancestor = current.superview
            }
            return nil
        }

        @MainActor
        private func findFirstTableView(in root: NSView) -> NSTableView? {
            if let tableView = root as? NSTableView {
                return tableView
            }
            for child in root.subviews {
                if let found = findFirstTableView(in: child) {
                    return found
                }
            }
            return nil
        }

        @MainActor
        private func bindObservers(to scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            let boundsObs = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let userInitiated = self.isLikelyUserScroll()
                    if userInitiated {
                        self.onUserScrollActivity()
                    }
                    self.emitMetrics(userInitiated: userInitiated)
                }
            }
            observers.append(boundsObs)

            let startObs = NotificationCenter.default.addObserver(
                forName: NSScrollView.willStartLiveScrollNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLiveScrolling = true
                    self.onUserScrollActivity()
                }
            }
            observers.append(startObs)

            let endObs = NotificationCenter.default.addObserver(
                forName: NSScrollView.didEndLiveScrollNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isLiveScrolling = false
                    self.onUserScrollActivity()
                    self.emitMetrics(userInitiated: true)
                }
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
                    Task { @MainActor [weak self] in
                        self?.emitMetrics(userInitiated: false)
                    }
                }
                observers.append(frameObs)
            }
        }

        @MainActor
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

        @MainActor
        private func emitMetrics(userInitiated: Bool) {
            guard let scrollView,
                  let documentView = scrollView.documentView else { return }
            let clip = scrollView.contentView
            let visibleBottom = clip.bounds.maxY
            let contentHeight = documentView.bounds.height
            let distanceToBottom = contentHeight - visibleBottom
            let atBottom = distanceToBottom <= Self.bottomEpsilon
            guard lastAtBottom != atBottom || lastUserInitiated != userInitiated else {
                return
            }
            lastAtBottom = atBottom
            lastUserInitiated = userInitiated
            let onMetricsChanged = onMetricsChanged
            DispatchQueue.main.async {
                onMetricsChanged(atBottom, userInitiated)
            }
        }

        @MainActor
        private func removeObservers() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            observers.removeAll()
            documentView?.postsFrameChangedNotifications = false
            scrollView?.contentView.postsBoundsChangedNotifications = false
            documentView = nil
            scrollView = nil
            isLiveScrolling = false
            lastAtBottom = nil
            lastUserInitiated = nil
        }
    }
}


private extension NSScrollView {
    func scrollToDocumentBottom() {
        guard let documentView else { return }
        documentView.layoutSubtreeIfNeeded()
        let clipView = contentView
        let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
        guard abs(clipView.bounds.origin.y - maxY) > 0.5 else { return }
        clipView.scroll(to: NSPoint(x: 0, y: maxY))
        reflectScrolledClipView(clipView)
    }
}

// MARK: - Preview

#Preview("MessageListView - Small") {
    MessageListView()
        .inRootView()
        .padding()
        .background(Color.black)
        .frame(width: 800, height: 600)
}

#Preview("MessageListView - Large") {
    MessageListView()
        .inRootView()
        .padding()
        .background(Color.black)
        .frame(width: 1200, height: 1200)
}
