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
                .padding(.horizontal)
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
        .environment(\.preferOuterScroll, true)
        .accessibilityLabel("消息列表")
        .accessibilityHint("按时间顺序展示会话消息")
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
            .accessibilityLabel("显示更早消息")
            .accessibilityHint("展开更早加载的历史消息")
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
            .accessibilityLabel("加载更早消息")
            .accessibilityHint("从历史记录中继续加载更早的消息")
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
        guard let sid = timelineViewModel.selectedConversationId,
              let vmMessage = conversationSendStatusVM.statusMessage(for: sid)
        else { return nil }
        return DisplayRow(id: vmMessage.id, message: vmMessage, relatedToolOutputs: [])
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
