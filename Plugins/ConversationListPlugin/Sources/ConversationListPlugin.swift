import AppKit
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ConversationListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let name = "Conversation List"
    public let order = 76
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // 注册工具栏会话列表按钮
        let toolbarItem = TitleToolbarItem(
            id: "\(id).conversation-list",
            title: "Chats",
            placement: .trailing
        ) {
            ConversationListToolbarButton(kernel: kernel)
        }
        kernel.toolbarProvider?.registerTitleToolbarItem(toolbarItem)
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Panel Rail Tab Items

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "chats",
                title: "Chats",
                systemImage: "message.fill"
            ) {
                ConversationRailView(kernel: kernel)
            },
        ]
    }
}

// MARK: - Toolbar Button

/// 工具栏会话列表按钮
struct ConversationListToolbarButton: View {
    let kernel: LumiKernel
    @State private var isPresented = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppIconButton(
                systemImage: "message.fill",
                label: LumiPluginLocalization.string("Chats", bundle: .module)
            ) {
                isPresented.toggle()
            }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                ConversationListPopoverContent(kernel: kernel)
                    .frame(width: 300, height: 480)
            }
        }
    }
}

// MARK: - Popover Content

/// 会话列表弹窗内容
struct ConversationListPopoverContent: View {
    let kernel: LumiKernel
    @State private var refreshTrigger = 0

    private static let notifications = Notification.Name("com.coffic.lumi.conversationsDidChange")

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var conversationList: [LumiConversationSummary] {
        _ = refreshTrigger
        return conversations?.conversations ?? []
    }

    private var dataDirectory: URL? {
        conversations?.dataDirectory
    }

    private func openDataDirectory() {
        guard let url = dataDirectory else { return }
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        contentView
    }

    @ViewBuilder
    private var contentView: some View {
        if let conv = conversations {
            conversationListView(conv)
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Conversations")
                .font(.headline)
            Text("Service not available")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private func conversationListView(_ conv: any ConversationManaging) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
                Button(action: openDataDirectory) {
                    Image(systemName: "folder")
                }
                .help("Open data directory")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            let list = conversationList
            if list.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No conversations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(list) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        llmProvider: kernel.llmProvider,
                        isSelected: conv.selectedConversationID == conversation.id,
                        onSelect: {
                            conv.selectConversation(id: conversation.id)
                            refreshTrigger += 1
                        },
                        onDelete: {
                            conv.deleteConversation(id: conversation.id)
                            refreshTrigger += 1
                        }
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.notifications)) { _ in
            refreshTrigger += 1
        }
    }
}
