import LumiCoreChat
import LumiCoreMessage
import LumiUI
import SwiftUI

struct ChatTimelineStatusBarView: View {
    @ObservedObject var chatService: LumiCoreChat.ChatService

    var body: some View {
        StatusBarHoverContainer(
            detailView: ChatTimelineDetailView(chatService: chatService),
            popoverWidth: 520,
            id: "chat-timeline"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "timeline.selection")
                    .font(.appMicroEmphasized)
                Text(messageCountLabel)
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var messageCountLabel: String {
        guard let conversationID = chatService.selectedConversationID else {
            return "0"
        }
        return "\(chatService.messages(for: conversationID).count)"
    }
}

private struct ChatTimelineDetailView: View {
    @LumiTheme private var theme
    @ObservedObject var chatService: LumiCoreChat.ChatService

    var body: some View {
        let contextUsage = chatService.selectedConversationID.map {
            chatService.conversationContextUsage(for: $0)
        }

        StatusBarPopoverScaffold(
            title: "Conversation Timeline",
            systemImage: "timeline.selection",
            subtitle: timelineSubtitle(contextUsage: contextUsage),
            headerAccessory: { EmptyView() },
            content: {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if let conversationID = chatService.selectedConversationID {
                            ForEach(chatService.messages(for: conversationID).suffix(30)) { message in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(message.role.rawValue.capitalized)
                                        .font(.appCaptionEmphasized)
                                        .foregroundColor(theme.textSecondary)
                                    Text(message.content)
                                        .font(.appCaption)
                                        .foregroundColor(theme.textPrimary)
                                        .lineLimit(3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .frame(minHeight: 280, maxHeight: 420)
            },
            footer: { EmptyView() }
        )
    }

    private func timelineSubtitle(contextUsage: LumiConversationContextUsage?) -> String {
        guard let contextUsage, contextUsage.currentTokens > 0 else {
            return "Recent messages"
        }
        if contextUsage.limit > 0 {
            return "Context \(contextUsage.label)"
        }
        return "Context \(LumiConversationContextUsage.formatToken(contextUsage.currentTokens))"
    }
}
