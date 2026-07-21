import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

/// Message List View
///
/// Displays the chat message list for the selected conversation.
struct MessageListView: View {
    let kernel: LumiKernel

    @LumiTheme private var theme
    @State private var messages: [LumiChatMessage] = []
    @State private var hasSelectedConversation = false

    private var isEmpty: Bool {
        messages.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if isEmpty && hasSelectedConversation {
                emptyStateView
            } else if !hasSelectedConversation {
                noConversationView
            } else {
                messageListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .onAppear {
            loadMessages()
        }
        .task(id: kernel.conversations?.selectedConversationID) {
            loadMessages()
        }
    }

    private var messageListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    MessageBubble(message: message)
                }
            }
            .padding(16)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text("No messages yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Start the conversation by sending a message.")
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noConversationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text("No conversation selected")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Select or create a conversation to start chatting.")
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadMessages() {
        guard let conversationID = kernel.conversations?.selectedConversationID else {
            messages = []
            hasSelectedConversation = false
            return
        }
        hasSelectedConversation = true
        messages = kernel.messageManager?.messages(for: conversationID) ?? []
    }
}
