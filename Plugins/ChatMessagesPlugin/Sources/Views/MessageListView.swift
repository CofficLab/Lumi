import LumiCoreKit
import LumiUI
import MarkdownKit
import SwiftUI

public struct MessageListView: View {
    private static let bottomAnchorId = "message-list-bottom-anchor"

    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject private var conversationVM: LumiCoreKit.WindowConversationVM
    @StateObject private var timelineViewModel = WindowChatTimelineViewModel()
    @State private var scrollToBottomRequest: UInt64 = 0
    @State private var shouldScrollToBottomOnRowsChange = true

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
            requestScrollToBottom()
        }
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            requestScrollToBottom()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("messageSaved"))) { notification in
            guard let message = notification.object as? ChatMessage,
                  let conversationId = notification.userInfo?["conversationId"] as? UUID
            else { return }
            timelineViewModel.handleMessageSaved(message, conversationId: conversationId)
            if conversationId == timelineViewModel.selectedConversationId {
                requestScrollToBottom()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("agentInputDidSendMessage"))) { _ in
            requestScrollToBottom()
            timelineViewModel.handleUserDidSendMessage()
        }
        .environmentObject(timelineViewModel)
    }
}

private extension MessageListView {
    func messageListView(displayRows: [ChatMessage]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if timelineViewModel.hasMoreMessages {
                        loadMoreButton
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
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
                    }

                    bottomAnchor
                }
            }
            .environment(\.preferOuterScroll, true)
            .accessibilityLabel(String(localized: "Message List", bundle: .module))
            .accessibilityHint(String(localized: "Message List Hint", bundle: .module))
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false, settleLayout: true)
                shouldScrollToBottomOnRowsChange = false
            }
            .onChange(of: displayRows.map(\.id)) { _, _ in
                guard shouldScrollToBottomOnRowsChange else { return }
                scrollToBottom(proxy: proxy, animated: true)
                shouldScrollToBottomOnRowsChange = false
            }
            .onChange(of: timelineViewModel.initialLoadVersion) { _, _ in
                scrollToBottom(proxy: proxy, animated: false, settleLayout: true)
                shouldScrollToBottomOnRowsChange = false
            }
            .onChange(of: scrollToBottomRequest) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id(Self.bottomAnchorId)
            .accessibilityHidden(true)
    }

    func requestScrollToBottom() {
        shouldScrollToBottomOnRowsChange = true
        scrollToBottomRequest &+= 1
    }

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool, settleLayout: Bool = false) {
        func performScroll(animated: Bool) {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(Self.bottomAnchorId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(Self.bottomAnchorId, anchor: .bottom)
            }
        }

        DispatchQueue.main.async {
            performScroll(animated: animated)
            guard settleLayout else { return }

            DispatchQueue.main.async {
                performScroll(animated: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                performScroll(animated: false)
            }
        }
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
