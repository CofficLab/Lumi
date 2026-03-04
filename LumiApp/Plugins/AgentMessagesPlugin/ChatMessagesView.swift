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

    /// 提示词服务
    private let promptService = PromptService.shared

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
            .onChange(of: conversationViewModel.messages) { oldMessages, newMessages in
                guard let lastMessage = newMessages.last else { return }

                // 如果是新消息，则滚动并带动画
                if oldMessages.last?.id != lastMessage.id {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                } else {
                    // 如果是同一条消息（流式更新），直接滚动以减少布局闪烁
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
            .task(id: conversationViewModel.currentConversation?.id) {
                // 当会话改变时，检查是否为空会话并插入欢迎消息
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

            let projectName = agentProvider.currentProjectName
            let projectPath = agentProvider.currentProjectPath
            let language = agentProvider.languagePreference

            let welcomeMessage = await promptService.getEmptySessionWelcomeMessage(
                projectName: projectName.isEmpty ? nil : projectName,
                projectPath: projectPath.isEmpty ? nil : projectPath,
                language: language
            )

            agentProvider.appendMessage(ChatMessage(role: .assistant, content: welcomeMessage))
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
        .frame(width: 800, height: 600)
        .background(Color.black)
        .inRootView()
}
