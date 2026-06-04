import LumiCoreKit
import LumiUI
import MarkdownKit
import SwiftUI

public struct MessageListView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject private var conversationVM: LumiCoreKit.WindowConversationVM
    @StateObject private var timelineViewModel = WindowChatTimelineViewModel()

    private let messageRenderer: (ChatMessage, Binding<Bool>) -> AnyView?

    public init(
        messageRenderer: @escaping (ChatMessage, Binding<Bool>) -> AnyView? = { _, _ in nil }
    ) {
        self.messageRenderer = messageRenderer
    }

    public var body: some View {
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
            timelineViewModel.configure(conversationVM: conversationVM)
        }
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            timelineViewModel.handleConversationChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("messageSaved"))) { notification in
            guard let message = notification.object as? ChatMessage,
                  let conversationId = notification.userInfo?["conversationId"] as? UUID
            else { return }
            timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("agentInputDidSendMessage"))) { _ in
            timelineViewModel.handleUserDidSendMessage()
        }
        .environmentObject(timelineViewModel)
    }
}

private extension MessageListView {
    func messageListView(displayRows: [ChatMessage]) -> some View {
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
                    isStreaming: false,
                    messageRenderer: messageRenderer
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
        .accessibilityLabel(String(localized: "Message List", bundle: .module))
        .accessibilityHint(String(localized: "Message List Hint", bundle: .module))
    }

    var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(String(localized: "Loading History", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var loadMoreButton: some View {
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
                .accessibilityLabel(String(localized: "Load Earlier Messages", bundle: .module))
                .accessibilityHint(String(localized: "Load Earlier Messages Hint", bundle: .module))
            } else {
                AppButton(
                    loadMoreButtonText,
                    systemImage: "arrow.up.circle",
                    style: .tonal,
                    size: .small
                ) {
                    timelineViewModel.handleLoadMore()
                }
                .accessibilityLabel(String(localized: "Load Earlier Messages", bundle: .module))
                .accessibilityHint(String(localized: "Load Earlier Messages Hint", bundle: .module))
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    var loadMoreButtonText: String {
        if timelineViewModel.isLoadingMore {
            return String(localized: "Loading More Messages", bundle: .module)
        }
        let loadedCount = timelineViewModel.persistedMessages.count
        return String(
            format: String(localized: "Load More Messages (%lld of %lld)", bundle: .module),
            loadedCount,
            timelineViewModel.totalMessageCount
        )
    }
}
