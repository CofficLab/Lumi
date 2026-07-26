import LumiKernel
import LumiUI
import MarkdownKit
import SuperLogKit
import SwiftUI
import os

/// Message List View
///
/// Displays the chat message list for the selected conversation.
struct MessageListView: View, SuperLog {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme
    @State private var messages: [LumiChatMessage] = []
    @State private var paging = MessageListPagingState()
    @State private var hasEarlierMessages = false
    @State private var hasSelectedConversation = false
    @State private var showRawMessage = false

    private let messagePageSize = 10
    private static let bottomAnchorID = "message-list-bottom"

    private var isEmpty: Bool {
        messages.isEmpty && !isSending
    }

    private var isSending: Bool {
        kernel.messageSender?.isSending ?? false
    }

    /// Display messages with a transient status message appended when sending.
    /// 工具调用结果消息的过滤已在 MessageManager.messages(for:) 中完成。
    private var displayMessages: [LumiChatMessage] {
        guard let conversationID = kernel.conversations?.selectedConversationID else {
            return messages
        }
        if isSending {
            let statusMessage = LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: "正在发送消息…",
                metadata: ["isTransientStatus": "true"]
            )
            return messages + [statusMessage]
        }
        return messages
    }

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    // MARK: - SuperLog

    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) public static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "message-list.view")

    var body: some View {
        VStack(spacing: 0) {
            if kernel.messageRendererManager == nil {
                MessageRendererUnavailableView()
            } else if isEmpty && hasSelectedConversation {
                MessageEmptyStateView()
            } else if !hasSelectedConversation {
                MessageNoConversationView()
            } else {
                messageListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .onAppear {
            if Self.verbose {
                Self.logger.info("\(Self.t)MessageListView appeared")
            }
            loadMessages()
        }
        .onChange(of: selectedConversationID) { _, newValue in
            if Self.verbose {
                Self.logger.info("\(Self.t)Conversation changed: \(newValue?.uuidString.prefix(8) ?? "nil")")
            }
            paging.resetForConversationChange()
            loadMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("com.coffic.lumi.messagesDidChange"))) { _ in
            guard paging.shouldAutoRefreshLatestOnMessageChange else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)Messages changed notification received")
            }
            loadMessages()
        }
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            List {
                if hasEarlierMessages {
                    Button(action: loadEarlierMessages) {
                        Text("Load earlier messages")
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }

                ForEach(displayMessages) { message in
                    MessageRowView(
                        message: message,
                        renderer: kernel.messageRendererManager?.renderer(for: message),
                        showRawMessage: $showRawMessage
                    )
                    .id(message.id)
                    .padding(.horizontal, ChatMessageListLayout.messageRowHorizontalPadding)
                    .padding(.vertical, ChatMessageListLayout.messageRowVerticalPadding)
                    .listRowInsets(ChatMessageListLayout.messageRowInsets)
                    .listRowSeparator(.hidden)
                }

                bottomAnchor
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.preferOuterScroll, ChatMessageListLayout.prefersOuterScrollForMarkdown)
            .onAppear {
                // 视图首次出现时（进入会话 / 从空状态切到有消息）定位到最底部，
                // 让用户直接看到最新消息。
                if Self.verbose {
                    Self.logger.info("\(Self.t)messageListView appeared, scroll to bottom")
                }
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: displayMessages.last?.id) { _, _ in
                // 用户刚刚发送消息时，消息列表末尾为 `.user` 角色的消息；
                // 此时强制滚动到最底部，确保用户立即看到自己刚发出的内容。
                guard let last = messages.last, last.role == .user else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)user message detected, scroll to bottom")
                }
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    /// 将消息列表滚动到最底部。
    ///
    /// - Parameter proxy: `ScrollViewReader` 提供的滚动代理。
    /// - Parameter animated: 是否使用动画。首次定位建议关闭动画以避免初次闪烁；
    ///   用户发送消息触发的滚动开启动画，过渡更自然。
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard !displayMessages.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    private var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id(Self.bottomAnchorID)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private func loadEarlierMessages() {
        Task { await loadEarlierMessagesAsync() }
    }

    private func loadMessages() {
        Task { await loadMessagesAsync() }
    }

    @MainActor
    private func loadEarlierMessagesAsync() async {
        guard let conversationID = selectedConversationID else { return }
        guard let manager = kernel.messageManager else { return }

        let olderPage = await manager.visibleMessages(
            for: conversationID,
            limit: messagePageSize,
            beforeMessageID: paging.oldestVisibleMessageID
        )
        guard !olderPage.isEmpty else { return }

        messages = olderPage + messages
        paging.didLoadEarlierPage(firstMessageID: messages.first?.id)
        hasEarlierMessages = await manager.hasEarlierMessages(
            for: conversationID,
            beforeMessageID: paging.oldestVisibleMessageID
        )
    }

    @MainActor
    private func loadMessagesAsync() async {
        guard let conversationID = selectedConversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)No conversation selected, clearing messages")
            }
            messages = []
            hasSelectedConversation = false
            hasEarlierMessages = false
            return
        }
        hasSelectedConversation = true
        // 只加载当前窗口的一页消息,避免把整段历史一次性拉入内存。
        guard let manager = kernel.messageManager else {
            messages = []
            hasEarlierMessages = false
            return
        }

        let loaded = await manager.visibleMessages(
            for: conversationID,
            limit: messagePageSize,
            beforeMessageID: nil
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)Loaded \(loaded.count) messages for conversation \(conversationID.uuidString.prefix(8))")
        }
        messages = loaded
        paging.didLoadLatestPage(firstMessageID: loaded.first?.id)
        hasEarlierMessages = await manager.hasEarlierMessages(
            for: conversationID,
            beforeMessageID: paging.oldestVisibleMessageID
        )
    }
}
