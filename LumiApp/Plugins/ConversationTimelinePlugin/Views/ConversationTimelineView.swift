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
    @State private var totalTokens: Int = 0

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

                        if totalTokens > 0 {
                            Divider().frame(height: 12)
                            Text(formatToken(totalTokens))
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

    /// 刷新消息数量和 token 总数
    private func refreshMessageCount() {
        guard let conversationId = conversationVM.selectedConversationId else {
            messageCount = 0
            totalTokens = 0
            return
        }
        if let messages = chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) {
            messageCount = messages.count
            totalTokens = messages.reduce(0) {
                $0 + ($1.inputTokens ?? 0) + ($1.outputTokens ?? 0)
            }
        } else {
            messageCount = 0
            totalTokens = 0
        }
    }
}
