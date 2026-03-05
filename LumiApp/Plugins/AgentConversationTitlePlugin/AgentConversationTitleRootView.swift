import SwiftUI
import OSLog
import MagicKit

/// Agent Conversation Title Root View Wrapper
/// 负责监听消息变化并生成会话标题
struct AgentConversationTitleRootViewWrapper<Content: View>: View {
    /// 视图内容
    var content: () -> Content

    /// 会话管理 ViewModel
    @EnvironmentObject var conversationViewModel: ConversationViewModel
    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider

    /// 插件实例
    private var plugin: AgentConversationTitlePlugin {
        AgentConversationTitlePlugin.shared
    }

    /// 日志标识
    private let emoji = "🏷️"
    /// 是否输出详细日志
    private let verbose = false

    /// 上次检查的消息数量
    @State private var lastMessageCount: Int = 0
    /// 是否已处理
    @State private var hasProcessed: Bool = false

    var body: some View {
        ZStack {
            content()

            // 隐藏的触发器视图
            Color.clear
                .frame(width: 1, height: 1)
                .onChange(of: conversationViewModel.messages.count) { _, newValue in
                    handleTitleGeneration(newCount: newValue)
                }
        }
    }
}

// MARK: - Event Handler

extension AgentConversationTitleRootViewWrapper {
    /// 处理标题生成
    private func handleTitleGeneration(newCount: Int) {
        // 避免重复处理
        guard !hasProcessed else { return }

        // 只有在首次收到用户消息时才生成标题
        guard lastMessageCount == 0, newCount > 0 else {
            return
        }

        // 获取第一条用户消息
        guard let firstUserMessage = conversationViewModel.messages.first(where: { $0.role == .user }) else {
            return
        }

        hasProcessed = true
        lastMessageCount = newCount

        Task {
            // 获取当前 LLM 配置
            let config = agentProvider.getCurrentConfig()

            // 调用插件生成标题
            await plugin.generateTitleIfNeeded(
                conversationViewModel: conversationViewModel,
                userMessage: firstUserMessage.content,
                hasGeneratedTitle: conversationViewModel.hasGeneratedTitle,
                currentConversation: conversationViewModel.currentConversation,
                config: config
            )
        }
    }
}

// MARK: - Title Generation (Internal)

extension AgentConversationTitlePlugin {
    /// 生成会话标题（如果是第一条用户消息）
    /// - Parameters:
    ///   - conversationViewModel: 会话管理 ViewModel
    ///   - userMessage: 用户消息内容
    ///   - hasGeneratedTitle: 是否已生成标题的标记
    ///   - currentConversation: 当前会话
    ///   - config: LLM 配置
    @MainActor func generateTitleIfNeeded(
        conversationViewModel: ConversationViewModel,
        userMessage: String,
        hasGeneratedTitle: Bool,
        currentConversation: Conversation?,
        config: LLMConfig
    ) async {
        // 只在以下条件下生成标题：
        // 1. 尚未生成过标题
        // 2. 当前对话是初始标题 "新会话 "
        // 3. 消息内容非空
        guard !hasGeneratedTitle,
              let conversation = currentConversation,
              conversation.title.hasPrefix("新会话 "),
              !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // 标记已生成标题
        conversationViewModel.setHasGeneratedTitleInternal(true)

        if Self.verbose {
            os_log("\(Self.emoji)🎯 开始为对话生成标题...")
        }

        // 生成标题
        let title = await conversationViewModel.generateConversationTitle(
            from: userMessage,
            config: config
        )

        // 更新对话标题
        conversationViewModel.updateConversationTitle(conversation, newTitle: title)

        if Self.verbose {
            os_log("\(Self.emoji)✅ 对话标题已生成：\(title)")
        }
    }
}

// MARK: - Preview

#Preview {
    AgentConversationTitleRootViewWrapper {
        Text("Preview Content")
    }
    .withDebugBar()
    .inRootView()
}
