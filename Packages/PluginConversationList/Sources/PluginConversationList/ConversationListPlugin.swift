import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderRailView
import SwiftUI

@MainActor
public final class ConversationListPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let order = 81
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // The list is a chat-side contribution in the new architecture. The
        // actual chat message list remains owned by PluginMessageList.
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else { return }
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        let railGroupID = "com.coffic.lumi.plugin.chat-panel"

        // The legacy chat workbench exposes its conversation browser in the
        // Rail, with the tab strip above it. Keep the contribution owned by
        // this plugin so the list can be removed independently at shutdown.
        rail?.addTabs([
            RailTabItem(
                id: "\(id).explorer",
                groupID: railGroupID,
                title: "Explorer",
                systemImage: "rectangle.grid.1x2",
                order: 10
            ) {
                RailPlaceholderView(title: "Explorer", systemImage: "rectangle.grid.1x2")
            },
            RailTabItem(
                id: "\(id).chat",
                groupID: railGroupID,
                title: "Chat",
                systemImage: "bubble.left.and.bubble.right",
                order: 20
            ) {
                ConversationBrowserView(conversations: conversations)
            },
            RailTabItem(
                id: "\(id).project",
                groupID: railGroupID,
                title: "Project",
                systemImage: "folder",
                order: 30
            ) {
                RailPlaceholderView(title: "Project", systemImage: "folder")
            }
        ])
        rail?.activateGroup(id: railGroupID)
        rail?.activateTab(id: "\(id).chat")
        chat.addBarItems([ChatSectionBarItem(id: id, order: 20, placement: .toolbarTrailing) {
            ConversationListToolbar(conversations: conversations)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeBarItem(id: id)
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: ["\(id).explorer", "\(id).chat", "\(id).project"])
    }
}

@MainActor
private struct RailPlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
private struct ConversationBrowserView: View {
    let conversations: any ConversationManaging
    @State private var revision = 0

    private var rows: [LumiConversationSummary] {
        _ = revision
        return conversations.sortedConversations
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("所有项目的对话")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if conversations.isLoadingConversations {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if rows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("暂无对话")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(rows) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: conversations.selectedConversationID == conversation.id
                            ) {
                                conversations.selectConversation(id: conversation.id)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                }
                .scrollIndicators(.automatic)
            }
        }
        .task {
            // ConversationManaging is an existential; polling keeps this
            // package independent of a concrete store implementation while
            // still refreshing after sends, renames, and selection changes.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                revision &+= 1
            }
        }
    }
}

@MainActor
private struct ConversationRow: View {
    let conversation: LumiConversationSummary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(conversation.displayTitle)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(conversation.updatedAt, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                if !conversation.preview.isEmpty {
                    Text(conversation.preview)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private struct ConversationListToolbar: View {
    let conversations: any ConversationManaging
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
            Text(conversations.currentTitle)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}
