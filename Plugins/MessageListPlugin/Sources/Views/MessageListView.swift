import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

/// Message List View
///
/// Displays the chat message list for the selected conversation.
struct MessageListView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme
    @State private var messages: [LumiChatMessage] = []
    @State private var hasSelectedConversation = false
    @State private var showRawMessage = false

    private var isEmpty: Bool {
        messages.isEmpty
    }

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
            loadMessages()
        }
        .onChange(of: kernel.conversations?.selectedConversationID) { _, _ in
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
            messages = []
            hasSelectedConversation = false
            return
        }
        hasSelectedConversation = true
        messages = kernel.messageManager?.messages(for: conversationID) ?? []
    }
}
