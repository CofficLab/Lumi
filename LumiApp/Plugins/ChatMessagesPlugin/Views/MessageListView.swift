import LumiUI
import AppKit
import SwiftUI
import MarkdownKit

/// 消息列表视图组件
struct MessageListView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject var timelineViewModel: WindowChatTimelineViewModel
    @EnvironmentObject var projectVM: WindowProjectVM

    var body: some View {
        let displayRows = timelineViewModel.visibleMessages

        Group {
            if displayRows.isEmpty {
                if timelineViewModel.isLoadingMore, timelineViewModel.selectedConversationId != nil {
                    loadingOverlay
                } else {
                    EmptyMessagesView()
                }
            } else {
                messageListView(displayRows: displayRows)
            }
        }
        .onAppear {
            timelineViewModel.handleOnAppear()
        }
        .onChange(of: timelineViewModel.selectedConversationId) { _, _ in
            // 会话切换时由 ViewModel 自动加载
        }
        .onMessageSaved { message, conversationId in
            timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
        }
        .onAgentInputDidSendMessage {
            timelineViewModel.handleUserDidSendMessage()
        }
    }
}

// MARK: - View

extension MessageListView {
    private func messageListView(displayRows: [ChatMessage]) -> some View {
        List {
            if timelineViewModel.hasMoreMessages {
                loadMoreButton
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
            }

            ForEach(displayRows) { message in
                ChatBubble(
                    message: message,
                    isLastMessage: message.id == displayRows.last?.id,
                    isStreaming: false
                )
                .id(message.id)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.preferOuterScroll, true)
        .accessibilityLabel(String(localized: "Message List", table: "AgentChat"))
        .accessibilityHint(String(localized: "Message List Hint", table: "AgentChat"))
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
