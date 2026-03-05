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
            .onChange(of: conversationViewModel.selectedConversationId, handleConversationSelected)
        }
    }
}

// MARK: - Actions

extension ChatMessagesView {

}

// MARK: Event Handler

extension ChatMessagesView {
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
