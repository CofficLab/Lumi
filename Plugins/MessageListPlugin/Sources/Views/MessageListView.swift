import LumiKernel
import LumiKernel
import LumiUI
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
    @State private var hasSelectedConversation = false
    @State private var showRawMessage = false

    private var isEmpty: Bool {
        messages.isEmpty && !isSending
    }

    private var isSending: Bool {
        kernel.messageSender?.isSending ?? false
    }

    /// 当前会话的回复详细级别
    private var currentVerbosity: LumiResponseVerbosity {
        let conversationID = kernel.conversations?.selectedConversationID
        return kernel.conversations?.verbosity(for: conversationID) ?? .defaultVerbosity
    }

    /// 工具调用结果消息（role == .tool）仅在「详细」(V3) 级别下展示。
    private var showsToolResultMessages: Bool {
        currentVerbosity == .detailed
    }

    /// Display messages with a transient status message appended when sending.
    /// 低于「详细」(V3) 级别时隐藏工具调用结果消息。
    private var displayMessages: [LumiChatMessage] {
        guard let conversationID = kernel.conversations?.selectedConversationID else {
            return messages
        }
        let visible: [LumiChatMessage]
        if showsToolResultMessages {
            visible = messages
        } else {
            visible = messages.filter { $0.role != .tool }
        }
        if isSending {
            let statusMessage = LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: "正在发送消息…",
                metadata: ["isTransientStatus": "true"]
            )
            return visible + [statusMessage]
        }
        return visible
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
        .onChange(of: kernel.conversations?.selectedConversationID) { _, newValue in
            if Self.verbose {
                Self.logger.info("\(Self.t)Conversation changed: \(newValue?.uuidString.prefix(8) ?? "nil")")
            }
            loadMessages()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("com.coffic.lumi.messagesDidChange"))) { _ in
            if Self.verbose {
                Self.logger.info("\(Self.t)Messages changed notification received")
            }
            loadMessages()
        }
    }

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(displayMessages) { message in
                        MessageRowView(
                            message: message,
                            renderer: kernel.messageRendererManager?.renderer(for: message),
                            showRawMessage: $showRawMessage
                        )
                        .id(message.id)
                    }
                }
                .padding(16)
            }
            .onAppear {
                // 视图首次出现时（进入会话 / 从空状态切到有消息）定位到最底部，
                // 让用户直接看到最新消息。
                if Self.verbose {
                    Self.logger.info("\(Self.t)messageListView appeared, scroll to bottom")
                }
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: messages.last?.id) { _, _ in
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
        guard let lastID = displayMessages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private func loadMessages() {
        guard let conversationID = kernel.conversations?.selectedConversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)No conversation selected, clearing messages")
            }
            messages = []
            hasSelectedConversation = false
            return
        }
        hasSelectedConversation = true
        let loaded = kernel.messageManager?.messages(for: conversationID) ?? []
        if Self.verbose {
            Self.logger.info("\(Self.t)Loaded \(loaded.count) messages for conversation \(conversationID.uuidString.prefix(8))")
        }
        messages = loaded
    }
}
