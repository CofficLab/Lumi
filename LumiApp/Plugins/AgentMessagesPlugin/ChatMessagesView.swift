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

    /// 标记是否正在加载会话，避免在加载过程中滚动
    @State private var isReloadingConversation = false

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
            .onConversationSelected(perform: handleConversationSelected)
            .task(id: conversationViewModel.currentConversation?.id) {
                // 切换会话时，等待消息加载后滚动到底部
                guard conversationViewModel.currentConversation != nil else { return }

                isReloadingConversation = true

                // 等待消息加载完成（让 SwiftData 和 Textual 完成布局）
                try? await Task.sleep(for: .milliseconds(150))

                if !Task.isCancelled, let lastMessage = conversationViewModel.messages.last {
                    lastMessageId = lastMessage.id

                    // 再次延迟，让 Textual 框架完成所有消息的布局
                    try? await Task.sleep(for: .milliseconds(100))

                    if !Task.isCancelled {
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                            isReloadingConversation = false
                        }
                    }
                } else {
                    isReloadingConversation = false
                }

                // 如果为空会话，插入欢迎消息
                await checkAndInsertWelcomeMessage()
            }
            .task(id: conversationViewModel.messages.last?.id) {
                // 仅在当前会话有新消息时滚动到底部（不是切换会话时）
                guard conversationViewModel.currentConversation != nil else { return }
                guard !isReloadingConversation else { return }
                guard let lastMessage = conversationViewModel.messages.last else { return }

                // 避免重复滚动到同一条消息
                if lastMessageId != lastMessage.id {
                    lastMessageId = lastMessage.id

                    // 延迟执行，避免与文本布局冲突
                    try? await Task.sleep(for: .milliseconds(50))

                    if !Task.isCancelled {
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
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
