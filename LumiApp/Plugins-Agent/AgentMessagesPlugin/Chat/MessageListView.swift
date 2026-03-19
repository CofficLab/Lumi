import MagicKit
import SwiftUI

/// 消息列表视图组件
struct MessageListView: View, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let defaultHistoryWindowLimit = 80
    nonisolated static let historyWindowStep = 40

    @EnvironmentObject var timelineViewModel: ChatTimelineViewModel
    @EnvironmentObject var processingStateViewModel: ProcessingStateVM
    @EnvironmentObject var thinkingStateViewModel: ThinkingStateVM

    private let bottomAnchorId = "chat_message_list_bottom_anchor"
    private let processingStatusRowId = UUID(uuidString: "9D735D22-588A-4B50-9B14-28C358CF5136")!
    private let thinkingStatusRowId = UUID(uuidString: "7F9E66FA-86F2-4A2A-B311-4A4EA75E1EC4")!
    @State private var historyWindowLimit = Self.defaultHistoryWindowLimit
    @State private var shouldPinLatestUserMessageToTop = false
    @State private var keepLatestUserMessageAtTop = false
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var lastScrollOffsetY: CGFloat = 0
    @State private var isActivelyScrolling: Bool = false
    @State private var scrollIdleWorkItem: DispatchWorkItem?
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
                timelineViewModel.handleOnAppear()
            }
            .onChange(of: timelineViewModel.selectedConversationId) { _, _ in
                historyWindowLimit = Self.defaultHistoryWindowLimit
                shouldPinLatestUserMessageToTop = false
                keepLatestUserMessageAtTop = false
            }
            .onChange(of: displayRows.last?.id) { _, _ in
                handleLastMessageChanged(proxy: proxy)
            }
            .onMessageSaved { message, conversationId in
                timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
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
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: MessageListScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("message_list_scroll_space")).minY
                        )
                }
                .frame(height: 0)

                if hiddenLoadedHistoryCount > 0 {
                    showEarlierLoadedButton(hiddenCount: hiddenLoadedHistoryCount)
                }

                if timelineViewModel.hasMoreMessages {
                    loadMoreButton
                }

                ForEach(displayRows) { row in
                    ChatBubble(
                        message: row.message,
                        isLastMessage: row.id == lastMessageID,
                        relatedToolOutputs: row.relatedToolOutputs,
                        isStreaming: false
                    )
                }

                Color.clear
                    .frame(height: 1)
                    .id(bottomAnchorId)

                if focusSpacerHeight > 0 {
                    Color.clear
                        .frame(height: focusSpacerHeight)
                }
            }
            .padding(.horizontal)
        }
        .environment(\.preferOuterScroll, true)
        .environment(\.chatListIsActivelyScrolling, isActivelyScrolling)
        .padding(.vertical)
        .coordinateSpace(name: "message_list_scroll_space")
        .onPreferenceChange(MessageListScrollOffsetPreferenceKey.self) { newOffset in
            handleScrollOffsetChanged(newOffset)
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
            Button {
                historyWindowLimit += Self.historyWindowStep
            } label: {
                Text("显示更早已加载消息（\(hiddenCount) 条）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加载历史消息…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadMoreButton: some View {
        HStack {
            Spacer()
            Button(action: timelineViewModel.handleLoadMore) {
                HStack(spacing: 8) {
                    if timelineViewModel.isLoadingMore {
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
            .disabled(timelineViewModel.isLoadingMore)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var loadMoreButtonText: String {
        if timelineViewModel.isLoadingMore {
            return "加载中..."
        }
        let loadedCount = timelineViewModel.persistedMessages.count
        return "加载更早消息（已加载 \(loadedCount) 条，共 \(timelineViewModel.totalMessageCount) 条）"
    }
}

// MARK: - Event Handlers

extension MessageListView {
    private func handleUserDidSendMessageEvent(proxy: ScrollViewProxy) {
        timelineViewModel.handleUserDidSendMessage()
        shouldPinLatestUserMessageToTop = true
        keepLatestUserMessageAtTop = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scrollLatestUserMessageToTop(proxy: proxy, animated: true)
        }
    }

    private func handleLastMessageChanged(proxy: ScrollViewProxy) {
        guard !windowedHistoryRows(from: timelineViewModel.persistedMessages).isEmpty else { return }

        if shouldPinLatestUserMessageToTop {
            scrollLatestUserMessageToTop(proxy: proxy, animated: false)
            shouldPinLatestUserMessageToTop = false
            keepLatestUserMessageAtTop = true
            timelineViewModel.disableAutoFollow()
            return
        }

        if timelineViewModel.shouldPerformInitialScrollAfterMessageChange() {
            scrollToBottom(proxy: proxy, animated: false)
            return
        }

        if timelineViewModel.shouldAutoFollow {
            scrollToBottom(proxy: proxy, animated: true)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
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
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(latestUserMessageId, anchor: .top)
            }
        } else {
            proxy.scrollTo(latestUserMessageId, anchor: .top)
        }
    }

    private func handleScrollOffsetChanged(_ newOffset: CGFloat) {
        let delta = newOffset - lastScrollOffsetY

        if abs(delta) >= 1 {
            if !isActivelyScrolling {
                isActivelyScrolling = true
            }

            scrollIdleWorkItem?.cancel()
            let work = DispatchWorkItem {
                isActivelyScrolling = false
            }
            scrollIdleWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }

        lastScrollOffsetY = newOffset
    }

    private func latestVisibleUserMessageId() -> UUID? {
        windowedHistoryRows(from: timelineViewModel.persistedMessages)
            .last(where: { $0.role == .user })?
            .id
    }

    private func buildDisplayRows(from messages: [ChatMessage], statusRow: DisplayRow? = nil) -> [DisplayRow] {
        var rows = messages.map { message in
            return DisplayRow(
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
        if processingStateViewModel.hasActiveLoading {
            let message = ChatMessage(
                id: processingStatusRowId,
                role: .status,
                content: processingStateViewModel.statusText,
                timestamp: Date(),
                isTransientStatus: true
            )
            return DisplayRow(id: message.id, message: message, relatedToolOutputs: [])
        }

        if thinkingStateViewModel.isThinking {
            let message = ChatMessage(
                id: thinkingStatusRowId,
                role: .status,
                content: "思考中…",
                timestamp: Date(),
                isTransientStatus: true
            )
            return DisplayRow(id: message.id, message: message, relatedToolOutputs: [])
        }

        return nil
    }
}

private struct MessageListScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview("MessageListView - Small") {
    MessageListView()
        .padding()
        .background(Color.black)
        .frame(width: 800, height: 600)
}

#Preview("MessageListView - Large") {
    MessageListView()
        .padding()
        .background(Color.black)
        .frame(width: 1200, height: 1200)
}
