import MagicKit
import SwiftUI
import Foundation

// MARK: - 详情视图

/// 对话时间线详情视图（在 Popover 中显示）
struct ConversationTimelineDetailView: View, SuperLog {
    nonisolated static let emoji = "📅"
    nonisolated static let verbose: Bool = false

    let conversationId: UUID
    @EnvironmentObject private var chatHistoryVM: AppChatHistoryVM
    @EnvironmentObject private var llmVM: AppLLMVM
    @State private var timelineItems: [MessageTimelineItem] = []
    private let timelineService = ConversationTimelineService()

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
        timelineItems = timelineService.timelineItems(from: messages)
    }

    // MARK: - 子视图

    /// 标题栏
    private var headerView: some View {
        ConversationTimelineHeader(
            itemCount: timelineItems.count,
            currentContextTokens: currentContextTokens,
            contextLimit: currentModelContextLimit,
            onRefresh: loadTimelineItems
        )
    }

    /// 获取当前模型的上下文窗口大小
    private var currentModelContextLimit: Int {
        timelineService.contextLimit(
            providerId: llmVM.selectedProviderId,
            model: llmVM.currentModel,
            providers: llmVM.availableProviders
        )
    }

    /// 当前上下文窗口使用量（用于判断是否接近模型上限）
    private var currentContextTokens: Int {
        timelineService.currentContextTokens(from: timelineItems)
    }

    /// 消息列表视图
    private var messageListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(timelineItems) { item in
                    MessageTimelineRow(item: item)
                }
            }
            .padding(16)
        }
    }
}
