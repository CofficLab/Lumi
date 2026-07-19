import LumiCoreChat
import LumiCoreMessage
import LumiUI
import SwiftUI

struct ChatPanelContentView: View {
    @LumiTheme private var theme

    var body: some View {
        if let chatService = ChatService.shared,
           let conversationID = chatService.selectedConversationID ?? chatService.conversations.first?.id {
            ConversationContentView(chatService: chatService, conversationID: conversationID)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(theme.textSecondary.opacity(0.5))

            Text("No conversation selected")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("Pick or start a conversation from the sidebar.")
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.workspaceBackground)
    }
}

private struct ConversationContentView: View {
    @ObservedObject var chatService: ChatService
    let conversationID: UUID

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chatService.messages(for: conversationID)) { message in
                        MessageRow(message: message)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(theme.workspaceBackground))
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Spacer()
        }
    }

    private var title: String {
        chatService.conversations.first(where: { $0.id == conversationID })?.title
            ?? "Chat"
    }
}

private struct MessageRow: View {
    @LumiTheme private var theme
    let message: LumiChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.rawValue.capitalized)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)

            Text(message.content)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.opacity(0.5))
        .cornerRadius(8)
    }
}
