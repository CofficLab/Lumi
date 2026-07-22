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
        messages.isEmpty
    }

    // MARK: - SuperLog

    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) public static var verbose = true
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    MessageRowView(
                        message: message,
                        renderer: kernel.messageRendererManager?.renderer(for: message),
                        showRawMessage: $showRawMessage
                    )
                }
            }
            .padding(16)
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
