import MagicKit
import SwiftUI
import Foundation

/// 对话时间线状态栏视图
struct ConversationTimelineView: View, SuperLog {
    nonisolated static let emoji = "📅"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var conversationVM: ConversationVM
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM
    @EnvironmentObject private var llmVM: LLMVM
    @State private var messageCount: Int = 0
    @State private var currentContextTokens: Int = 0
    private let timelineService = ConversationTimelineService()

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
                            Text(contextTokenLabel)
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
        .onChange(of: llmVM.currentModel) { _, _ in
            refreshMessageCount()
        }
        .onChange(of: llmVM.selectedProviderId) { _, _ in
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

    /// 格式化上下文 token 显示标签（如 "100k/200k"）
    private var contextTokenLabel: String {
        let limit = currentModelContextLimit
        if limit > 0 {
            return "\(timelineService.formatToken(currentContextTokens))/\(timelineService.formatToken(limit))"
        }
        return timelineService.formatToken(currentContextTokens)
    }

    /// 获取当前模型的上下文窗口大小
    private var currentModelContextLimit: Int {
        timelineService.contextLimit(
            providerId: llmVM.selectedProviderId,
            model: llmVM.currentModel,
            providers: llmVM.availableProviders
        )
    }

    /// 刷新消息数量和当前上下文 token 数
    private func refreshMessageCount() {
        guard let conversationId = conversationVM.selectedConversationId else {
            messageCount = 0
            currentContextTokens = 0
            return
        }
        if let messages = chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) {
            let summary = timelineService.summary(from: messages)
            messageCount = summary.messageCount
            currentContextTokens = summary.currentContextTokens
        } else {
            messageCount = 0
            currentContextTokens = 0
        }
    }
}
