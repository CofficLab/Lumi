import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatConversationListView: View {
    @LumiTheme private var theme

    let conversations: [LumiConversationSummary]
    let selectedID: UUID?
    let onCreateConversation: () -> Void
    let onSelectConversation: (UUID) -> Void
    let onDeleteConversation: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ChatDivider(axis: .horizontal)

            if conversations.isEmpty {
                AppEmptyState(icon: "bubble.left", title: "No conversations")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(conversations) { conversation in
                            ChatConversationRow(
                                conversation: conversation,
                                isSelected: conversation.id == selectedID,
                                onSelect: {
                                    onSelectConversation(conversation.id)
                                },
                                onDelete: {
                                    onDeleteConversation(conversation.id)
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Chats")
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)

            Spacer()

            AppIconButton(systemImage: "plus", size: .regular) {
                onCreateConversation()
            }
            .help("New Chat")
        }
        .padding(12)
    }
}

private struct ChatConversationRow: View {
    @LumiTheme private var theme

    let conversation: LumiConversationSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showsDeleteConfirmation = false

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conversation.title)
                        .font(.appCaptionEmphasized)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(conversation.updatedAt, style: .time)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }

                Text(conversation.preview.isEmpty ? "No messages yet" : conversation.preview)
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("Delete Conversation", systemImage: "trash")
            }
        }
        .alert("Delete Conversation", isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This conversation and its messages will be removed.")
        }
    }
}
