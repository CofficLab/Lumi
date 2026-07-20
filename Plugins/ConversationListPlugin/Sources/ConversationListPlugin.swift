import LumiKernel
import LumiCoreMessage
import LumiUI
import SwiftUI
import os

@MainActor
public final class ConversationListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let name = "Conversation List"
    public let order = 76

    public nonisolated static let verbose = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")
    public nonisolated static let t = "💬"

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
        kernel.titleToolbar?.registerTitleToolbarItem(toolbarItem)
    }

    public func boot(kernel: LumiKernel) async throws {}
}

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

/// 会话列表弹窗内容
struct ConversationListPopoverContent: View {
    let kernel: LumiKernel
    @State private var errorMessage: String?

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var conversationList: [LumiConversationSummary] {
        conversations?.conversations ?? []
    }

    var body: some View {
        if let error = errorMessage {
            errorView(error)
        } else if let conv = conversations {
            conversationListView(conv)
        } else {
            placeholderView("Conversations service not available")
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Chat Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private func placeholderView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Conversations")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private func conversationListView(_ conv: any ConversationManaging) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Conversations")
                    .font(.headline)
                Spacer()
                Button {
                    _ = conv.createConversation(title: nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding()

            Divider()

            // List
            if conversationList.isEmpty {
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
                List(conversationList) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        isSelected: conv.selectedConversationID == conversation.id,
                        onSelect: { conv.selectConversation(id: conversation.id) },
                        onDelete: { conv.deleteConversation(id: conversation.id) }
                    )
                }
            }
        }
    }
}

/// 对话行
struct ConversationRow: View {
    let conversation: LumiConversationSummary
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title.isEmpty ? "Untitled" : conversation.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(conversation.updatedAt.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}
