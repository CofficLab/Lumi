import MagicKit
import SwiftUI
import Foundation

// MARK: - 详情视图

/// 对话时间线详情视图（在 Popover 中显示）
struct ConversationTimelineDetailView: View, SuperLog {
    nonisolated static let emoji = "📅"
    nonisolated static let verbose: Bool = false

    let conversationId: UUID
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM
    @State private var timelineItems: [MessageTimelineItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            headerView

            // 消息时间线
            if timelineItems.isEmpty {
                ConversationTimelineEmptyState()
            } else {
                messageListView
            }
        }
        .frame(height: 800)
        .onAppear {
            loadTimelineItems()
        }
    }

    /// 加载时间线数据
    private func loadTimelineItems() {
        guard let messages = chatHistoryVM.loadMessagesAsync(forConversationId: conversationId) else {
            timelineItems = []
            return
        }
        timelineItems = messages
            .sorted { $0.timestamp < $1.timestamp }
            .map { msg in
                MessageTimelineItem(
                    id: msg.id,
                    role: msg.role,
                    content: msg.content,
                    timestamp: msg.timestamp,
                    hasToolCalls: msg.hasToolCalls,
                    isError: msg.isError,
                    providerId: msg.providerId,
                    modelName: msg.modelName,
                    inputTokens: msg.inputTokens,
                    outputTokens: msg.outputTokens
                )
            }
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        ConversationTimelineHeader(
            itemCount: timelineItems.count,
            totalTokens: totalTokens,
            onRefresh: loadTimelineItems
        )
    }

    /// 对话总 token 数
    private var totalTokens: Int {
        timelineItems.reduce(0) { $0 + ($1.inputTokens ?? 0) + ($1.outputTokens ?? 0) }
    }

    /// 消息列表视图
    private var messageListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(timelineItems) { item in
                    MessageTimelineRow(item: item)
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
}
