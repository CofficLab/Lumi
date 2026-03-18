import MagicKit
import OSLog
import SwiftUI

/// 消息列表视图组件
struct MessageListView: View, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = false
    nonisolated static let defaultHistoryWindowLimit = 80
    nonisolated static let historyWindowStep = 40

    @EnvironmentObject var timelineViewModel: ChatTimelineViewModel

    private let bottomAnchorId = "chat_message_list_bottom_anchor"
    @State private var historyWindowLimit = Self.defaultHistoryWindowLimit
    private struct DisplayRow: Identifiable {
        let id: UUID
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]
    }

    var body: some View {
        ScrollViewReader { proxy in
            let windowedPersistedRows = windowedHistoryRows(from: timelineViewModel.persistedMessages)
            let hiddenLoadedHistoryCount = max(0, timelineViewModel.persistedMessages.count - windowedPersistedRows.count)
            let displayRows = buildDisplayRows(from: windowedPersistedRows)
            let lastMessageID = displayRows.last?.id

            Group {
                if displayRows.isEmpty {
                    if timelineViewModel.isLoadingMore, timelineViewModel.selectedConversationId != nil {
                        loadingOverlay
                    } else {
                        EmptyMessagesView()
                    }
                } else {
                    messageScrollView(
                        lastMessageID: lastMessageID,
                        hiddenLoadedHistoryCount: hiddenLoadedHistoryCount
                    )
                }
            }
            .onAppear {
                historyWindowLimit = Self.defaultHistoryWindowLimit
                timelineViewModel.handleOnAppear()
            }
            .onChange(of: timelineViewModel.selectedConversationId) { _, _ in
                historyWindowLimit = Self.defaultHistoryWindowLimit
            }
            .onChange(of: windowedPersistedRows.last?.id) { _, _ in
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
    private func messageScrollView(lastMessageID: UUID?, hiddenLoadedHistoryCount: Int) -> some View {
        let windowedPersistedRows = windowedHistoryRows(from: timelineViewModel.persistedMessages)
        let displayRows = buildDisplayRows(from: windowedPersistedRows)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
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
            }
            .padding(.horizontal)
        }
        .environment(\.preferOuterScroll, true)
        .padding(.vertical)
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
        if Self.verbose {
            os_log("\(Self.t)📜 收到 AgentInput 用户发送消息事件，准备滚动到底部")
        }

        timelineViewModel.handleUserDidSendMessage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            scrollToBottom(proxy: proxy, animated: true)
        }
    }

    private func handleLastMessageChanged(proxy: ScrollViewProxy) {
        guard !windowedHistoryRows(from: timelineViewModel.persistedMessages).isEmpty else { return }

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

    private func buildDisplayRows(from messages: [ChatMessage]) -> [DisplayRow] {
        messages.map { message in
            DisplayRow(
                id: message.id,
                message: message,
                relatedToolOutputs: timelineViewModel.toolOutputs(for: message)
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
