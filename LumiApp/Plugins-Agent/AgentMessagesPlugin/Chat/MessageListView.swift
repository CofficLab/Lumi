import MagicKit
import OSLog
import SwiftUI

private struct ContentBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ViewportBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 消息列表视图组件
struct MessageListView: View, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose = false

    @EnvironmentObject var agentProvider: AgentVM
    @EnvironmentObject var timelineViewModel: ChatTimelineViewModel

    private let bottomAnchorId = "chat_message_list_bottom_anchor"
    private struct DisplayRow: Identifiable {
        let id: UUID
        let message: ChatMessage
        let relatedToolOutputs: [ChatMessage]
    }

    var body: some View {
        ScrollViewReader { proxy in
            let sourceRows = timelineViewModel.messages
            let displayRows = buildDisplayRows(from: sourceRows)
            let lastMessageID = displayRows.last?.id

            Group {
                if displayRows.isEmpty {
                    if timelineViewModel.isLoadingMore, timelineViewModel.selectedConversationId != nil {
                        loadingOverlay
                    } else {
                        EmptyMessagesView()
                    }
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        messageScrollView(lastMessageID: lastMessageID)

                        if !timelineViewModel.isNearBottom {
                            jumpToLatestButton(proxy: proxy)
                                .padding(.trailing, 16)
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
            .onAppear {
                timelineViewModel.handleOnAppear()
            }
            .onChange(of: sourceRows.last?.id) { _, _ in
                handleLastMessageChanged(proxy: proxy)
            }
            .onMessageSaved { message, conversationId in
                timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
            }
            .onAgentInputDidSendMessage {
                handleUserDidSendMessageEvent(proxy: proxy)
            }
            .onPreferenceChange(ContentBottomPreferenceKey.self) { value in
                timelineViewModel.updateBottomMetrics(contentBottomY: value)
            }
            .onPreferenceChange(ViewportBottomPreferenceKey.self) { value in
                timelineViewModel.updateBottomMetrics(viewportBottomY: value)
            }
        }
    }
}

// MARK: - View

extension MessageListView {
    private func messageScrollView(lastMessageID: UUID?) -> some View {
        let displayRows = buildDisplayRows(from: timelineViewModel.messages)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if timelineViewModel.hasMoreMessages {
                    loadMoreButton
                }

                ForEach(displayRows) { row in
                    ChatBubble(
                        message: row.message,
                        isLastMessage: row.id == lastMessageID,
                        relatedToolOutputs: row.relatedToolOutputs,
                        isStreaming: row.id == agentProvider.currentStreamingMessageId
                    )
                }

                Color.clear
                    .frame(height: 1)
                    .id(bottomAnchorId)
            }
            .padding(.horizontal)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ContentBottomPreferenceKey.self, value: geo.frame(in: .global).maxY)
                }
            )
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ViewportBottomPreferenceKey.self, value: geo.frame(in: .global).maxY)
            }
        )
        .environment(\.preferOuterScroll, true)
        .padding(.vertical)
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

    private func jumpToLatestButton(proxy: ScrollViewProxy) -> some View {
        Button {
            timelineViewModel.enableAutoFollow()
            scrollToBottom(proxy: proxy, animated: true)
        } label: {
            Label("跳转最新", systemImage: "arrow.down")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
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
        let displayCount = buildDisplayRows(from: timelineViewModel.messages).count
        return "加载更早消息（已加载 \(displayCount) 条，共 \(timelineViewModel.totalMessageCount) 条）"
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
        guard !timelineViewModel.messages.isEmpty else { return }

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

    /// 将 assistant(toolCalls) 后续关联的 tool 输出合并到同一行渲染，避免重复视觉噪音。
    private func buildDisplayRows(from messages: [ChatMessage]) -> [DisplayRow] {
        var result: [DisplayRow] = []
        var consumed = Set<UUID>()

        for (index, message) in messages.enumerated() {
            guard !consumed.contains(message.id) else { continue }

            if message.role == .assistant, let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                let validIds = Set(toolCalls.map(\.id))
                var related: [ChatMessage] = []
                var cursor = index + 1

                while cursor < messages.count {
                    let next = messages[cursor]
                    if consumed.contains(next.id) {
                        cursor += 1
                        continue
                    }

                    let isToolOutput = next.role == .tool || next.isToolOutput
                    if !isToolOutput { break }

                    if validIds.isEmpty || (next.toolCallID != nil && validIds.contains(next.toolCallID!)) {
                        related.append(next)
                        consumed.insert(next.id)
                        cursor += 1
                        continue
                    }

                    break
                }

                result.append(DisplayRow(id: message.id, message: message, relatedToolOutputs: related))
                continue
            }

            result.append(DisplayRow(id: message.id, message: message, relatedToolOutputs: []))
        }

        return result
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
