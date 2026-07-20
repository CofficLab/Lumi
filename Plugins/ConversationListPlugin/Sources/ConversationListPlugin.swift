import AppKit
import LumiKernel
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

    // MARK: - Panel Rail Tab Items

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "chats",
                title: "Chats",
                systemImage: "message.fill"
            ) {
                ConversationRailView(kernel: kernel)
            }
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
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var refreshTrigger = 0

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var conversationList: [LumiConversationSummary] {
        let _ = refreshTrigger
        return conversations?.conversations ?? []
    }

    private var dataDirectory: URL? {
        conversations?.dataDirectory
    }

    private func openDataDirectory() {
        guard let url = dataDirectory else { return }
        NSWorkspace.shared.open(url)
    }

    private func handleCreateConversation() {
        guard let conv = conversations else { return }
        do {
            _ = try conv.createConversation(title: nil)
            refreshTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    var body: some View {
        contentView
            .alert("创建对话失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
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
                Button(action: handleCreateConversation) {
                    Image(systemName: "plus")
                }
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
    }
}

// MARK: - Rail View

/// Rail 面板视图
struct ConversationRailView: View {
    let kernel: LumiKernel
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var refreshTrigger = 0

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var conversationList: [LumiConversationSummary] {
        let _ = refreshTrigger
        return conversations?.conversations ?? []
    }

    private func handleCreateConversation() {
        guard let conv = conversations else { return }
        do {
            _ = try conv.createConversation(title: nil)
            refreshTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    var body: some View {
        contentView
            .alert("创建对话失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if let conv = conversations {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Chats")
                        .font(.headline)
                    Spacer()
                    Button(action: handleCreateConversation) {
                        Image(systemName: "plus")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                let list = conversationList
                if list.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "message")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No conversations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(list) { conversation in
                        ConversationRow(
                            conversation: conversation,
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Service unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Conversation Row

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
