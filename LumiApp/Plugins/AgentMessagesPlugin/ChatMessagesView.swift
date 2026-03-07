import MagicKit
import OSLog
import SwiftUI

/// 聊天消息列表视图 - 可滚动的聊天历史记录
struct ChatMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    /// 消息管理 ViewModel
    @EnvironmentObject var messageViewModel: MessageViewModel
    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel
    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 非系统消息
    private var nonSystemMessages: [ChatMessage] {
        messageViewModel.messages.filter { $0.role != .system }
    }

    /// 是否已选择会话
    private var hasSelectedConversation: Bool {
        conversationViewModel.selectedConversationId != nil
    }

    /// 消息是否为空
    private var isMessagesEmpty: Bool {
        nonSystemMessages.isEmpty
    }

    var body: some View {
        Group {
            if hasSelectedConversation {
                if isMessagesEmpty {
                    emptyMessagesView
                } else {
                    messagesListView
                }
            } else {
                emptyStateView
            }
        }
        .onChange(of: conversationViewModel.selectedConversationId, handleConversationSelected)
    }
}

// MARK: - Subviews

extension ChatMessagesView {
    /// 消息列表视图
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(nonSystemMessages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .onChange(of: nonSystemMessages.count) {
                handleMessagesChanged(proxy: proxy)
            }
            .overlay {
                if let request = agentProvider.pendingPermissionRequest {
                    PermissionRequestView(
                        request: request,
                        onAllow: {
                            agentProvider.respondToPermissionRequest(allowed: true)
                        },
                        onDeny: {
                            agentProvider.respondToPermissionRequest(allowed: false)
                        }
                    )
                }
            }
        }
    }

    /// 空状态视图 - 未选择会话时显示（无动态效果）
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // 标题
            Text("选择一个会话开始聊天", tableName: "DevAssistant")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text("从左侧列表选择一个现有会话，或创建新会话", tableName: "DevAssistant")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }

    /// 空消息视图 - 已选择会话但没有消息时显示（带动态效果）
    private var emptyMessagesView: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
                .symbolEffect(.bounce, options: .repeating.speed(0.5))

            // 标题
            Text("暂无消息", tableName: "DevAssistant")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text("在下方输入框中输入您的问题，开始与 AI 助手对话", tableName: "DevAssistant")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Actions

extension ChatMessagesView {
    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = nonSystemMessages.last else { return }

        Task {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: Event Handler

extension ChatMessagesView {
    func handleMessagesChanged(proxy: ScrollViewProxy) {
        if Self.verbose {
            os_log("\(self.t)📬 消息数量变化，滚动到底部")
        }
        scrollToBottom(proxy: proxy)
    }

    func handleConversationSelected() {
        guard let conversationId = conversationViewModel.selectedConversationId else { return }

        if Self.verbose {
            os_log("\(self.t)✅ [\(conversationId)] 已选择")
        }

        // 注意：ConversationViewModel.selectConversation 已经调用了 loadConversation
        // 这里不需要再次加载，避免重复请求
        // Task {
        //     await conversationViewModel.loadConversation(conversationId)
        // }
    }
}

// MARK: - Preview

#Preview("With Messages") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
}

#Preview("Empty State") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
}