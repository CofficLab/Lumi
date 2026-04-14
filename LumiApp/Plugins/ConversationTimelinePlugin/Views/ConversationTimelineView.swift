import MagicKit
import SwiftUI
import Foundation

/// 对话时间线状态栏视图
struct ConversationTimelineView: View, SuperLog {
    nonisolated static let emoji = "📅"
    nonisolated static let verbose: Bool = false

    @EnvironmentObject private var conversationVM: ConversationVM
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM
    @State private var messageCount: Int = 0
    @State private var currentContextTokens: Int = 0

    var body: some View {
        Group {
            if let conversationId = conversationVM.selectedConversationId, messageCount > 0 {
                StatusBarHoverContainer(
                    detailView: ConversationTimelineDetailView(conversationId: conversationId),
                    popoverWidth: 500,
                    id: "conversation-timeline"
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 10))

                        Text("\(messageCount) 条")
                            .font(.system(size: 11))

                        if currentContextTokens > 0 {
                            Divider().frame(height: 12)
                            Text(formatToken(currentContextTokens))
                                .font(.system(size: 11))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            refreshMessageCount()
        }
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            refreshMessageCount()
        }
        .onMessageSaved { message, conversationId in
            // 只刷新当前选中对话的消息
            guard conversationId == conversationVM.selectedConversationId else { return }
            refreshMessageCount()
            
            if Self.verbose {
                AppLogger.core.info("\(Self.t)📬 收到消息保存事件，刷新统计: conversationId=\(conversationId)")
            }
        }
    }

    /// 刷新消息数量和当前上下文 token 数
    private func refreshMessageCount() {
        guard let conversationId = conversationVM.selectedConversationId else {
            messageCount = 0
            currentContextTokens = 0
            return
        }
        if let messages = chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) {
            messageCount = messages.count
            
            // 计算当前上下文窗口使用量
            // 1. 找到最后一条 assistant 消息
            let lastAssistant = messages.last(where: { $0.role == .assistant })
            
            // 2. 获取其 inputTokens 作为基础上下文
            let baseContext = lastAssistant?.inputTokens ?? 0
            
            // 3. 找出最后一条 assistant 之后的用户消息（尚未回复的新消息）
            let lastAssistantIndex = messages.firstIndex {
                $0.id == lastAssistant?.id
            } ?? -1
            
            let newMessagesAfterLastResponse: [ChatMessage]
            if lastAssistantIndex >= 0 && lastAssistantIndex < messages.count - 1 {
                newMessagesAfterLastResponse = Array(messages[(lastAssistantIndex + 1)...])
                    .filter { $0.role == .user }
            } else {
                newMessagesAfterLastResponse = []
            }
            
            // 4. 估算新增消息的 tokens（简单按字符/4 计算）
            let newTokens = newMessagesAfterLastResponse.reduce(0) {
                $0 + $1.content.count / 4
            }
            
            // 5. 当前上下文 = 最后一条 inputTokens + 新增用户消息
            currentContextTokens = baseContext + newTokens
        } else {
            messageCount = 0
            currentContextTokens = 0
        }
    }
}
