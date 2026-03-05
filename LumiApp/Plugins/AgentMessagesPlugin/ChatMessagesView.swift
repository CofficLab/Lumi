import MagicKit
import OSLog
import SwiftUI

/// 聊天消息列表视图 - 可滚动的聊天历史记录
struct ChatMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = false

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

    var body: some View {
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
            .onChange(of: conversationViewModel.selectedConversationId, handleConversationSelected)
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

        Task {
            await conversationViewModel.loadConversation(conversationId)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
}
