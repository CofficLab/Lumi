import MagicKit
import OSLog
import SwiftUI

/// 聊天消息列表视图 - 可滚动的聊天历史记录
struct ChatMessagesView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = true

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel
    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 跟踪最后一条消息的 ID，用于检测新消息
    @State private var lastMessageId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(conversationViewModel.messages.filter { $0.role != .system }) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal)
            }
            .id(conversationViewModel.currentConversation?.id)
            .onConversationSelected(perform: handleConversationSelected)
            .task(id: conversationViewModel.messages.last?.id) {
                // 当有新消息时，滚动到底部
                guard let lastMessage = conversationViewModel.messages.last else { return }

                // 避免重复滚动到同一条消息
                if lastMessageId != lastMessage.id {
                    lastMessageId = lastMessage.id

                    // 延迟执行，避免与文本布局冲突
                    try? await Task.sleep(for: .milliseconds(50))

                    if !Task.isCancelled {
                        await MainActor.run {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .task(id: conversationViewModel.currentConversation?.id) {
                await checkAndInsertWelcomeMessage()
            }
        }
    }
}

// MARK: - Actions

extension ChatMessagesView {
    /// 检查当前会话是否为空，如果为空则插入欢迎消息
    @MainActor
    private func checkAndInsertWelcomeMessage() async {
        // 过滤掉 system 角色的消息
        let nonSystemMessages = conversationViewModel.messages.filter { $0.role != .system }

        // 如果没有任何非系统消息，插入欢迎消息
        if nonSystemMessages.isEmpty {
            if Self.verbose {
                os_log("\(self.t) 当前会话为空，插入欢迎消息")
            }

            let welcomeMessage = await agentProvider.getEmptySessionWelcomeMessage()
            conversationViewModel.appendMessageInternal(ChatMessage(role: .assistant, content: welcomeMessage))
        }
    }
}

// MARK: Event Handler

extension ChatMessagesView {
    func handleConversationSelected(_ conversationId: UUID) {
        if Self.verbose {
            os_log("\(self.t) [\(conversationId)] 已选择")
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
        .inRootView("Preview")
}
