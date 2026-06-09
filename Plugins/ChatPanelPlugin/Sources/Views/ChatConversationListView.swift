import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatConversationListView: View {
    @LumiTheme private var theme

    let conversations: [LumiConversationSummary]
    let selectedID: UUID?
    let currentProjectPath: String?
    let isSending: (UUID) -> Bool
    let onCreateConversation: () -> Void
    let onSelectConversation: (UUID) -> Void
    let onDeleteConversation: (UUID) -> Void

    @State private var visibleLimit = 50
    @State private var filterByCurrentProject = false

    private var filteredConversations: [LumiConversationSummary] {
        guard filterByCurrentProject,
              let currentProjectPath,
              !currentProjectPath.isEmpty
        else {
            return conversations
        }
        return conversations.filter { $0.projectPath == currentProjectPath }
    }

    private var displayedConversations: [LumiConversationSummary] {
        Array(filteredConversations.prefix(visibleLimit))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ChatDivider(axis: .horizontal)

            if conversations.isEmpty {
                AppEmptyState(icon: "bubble.left", title: "No conversations")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredConversations.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: "No Project Chats",
                    description: "No conversations are linked to the current project."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(displayedConversations) { conversation in
                            ChatConversationRow(
                                conversation: conversation,
                                isSelected: conversation.id == selectedID,
                                isSending: isSending(conversation.id),
                                currentProjectPath: currentProjectPath,
                                onSelect: {
                                    onSelectConversation(conversation.id)
                                },
                                onDelete: {
                                    onDeleteConversation(conversation.id)
                                }
                            )
                        }

                        if displayedConversations.count < filteredConversations.count {
                            AppButton("Load More", systemImage: "arrow.down.circle", size: .small) {
                                visibleLimit += 50
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
        .onChange(of: conversations.count) { _, _ in
            if visibleLimit < 50 {
                visibleLimit = 50
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Chats")
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)

            if currentProjectPath?.isEmpty == false {
                AppIconButton(
                    systemImage: filterByCurrentProject ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle",
                    size: .regular
                ) {
                    filterByCurrentProject.toggle()
                }
                .help(filterByCurrentProject ? "Show all conversations" : "Show current project only")
            }

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
    let isSending: Bool
    let currentProjectPath: String?
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

                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    }

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

                if let projectPath = conversation.projectPath {
                    let name = URL(fileURLWithPath: projectPath).lastPathComponent
                    let isCurrent = projectPath == currentProjectPath
                    Text(isCurrent ? "\(name) (current)" : name)
                        .font(.appMicro)
                        .foregroundColor(isCurrent ? theme.primary : theme.textTertiary)
                        .lineLimit(1)
                }
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
