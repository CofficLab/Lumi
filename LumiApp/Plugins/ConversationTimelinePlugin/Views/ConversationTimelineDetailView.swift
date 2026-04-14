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
    @EnvironmentObject private var llmVM: LLMVM
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
            currentContextTokens: currentContextTokens,
            contextLimit: currentModelContextLimit,
            onRefresh: loadTimelineItems
        )
    }

    /// 获取当前模型的上下文窗口大小
    private var currentModelContextLimit: Int {
        let providerId = llmVM.selectedProviderId
        let model = llmVM.currentModel
        let providers = llmVM.availableProviders
        
        guard let provider = providers.first(where: { $0.id == providerId }) else {
            return 0
        }
        return provider.contextWindowSizes[model] ?? 0
    }

    /// 当前上下文窗口使用量（用于判断是否接近模型上限）
    private var currentContextTokens: Int {
        // 取最后一条 assistant 消息的 inputTokens 作为当前上下文基础
        let baseContext = timelineItems.last(where: { $0.role == .assistant })?.inputTokens ?? 0
        
        // 找出最后一条 assistant 之后的用户消息索引
        let lastAssistantIndex = timelineItems.firstIndex { $0.role == .assistant } ?? -1
        
        // 计算新增用户消息的 tokens
        let newTokens: Int
        if lastAssistantIndex >= 0 && lastAssistantIndex < timelineItems.count - 1 {
            let newMessages = timelineItems[(lastAssistantIndex + 1)...]
                .filter { $0.role == .user }
            // 用户消息通常没有 inputTokens，按内容长度估算（字符数/4）
            newTokens = newMessages.reduce(0) {
                $0 + $1.content.count / 4
            }
        } else {
            newTokens = 0
        }
        
        return baseContext + newTokens
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
