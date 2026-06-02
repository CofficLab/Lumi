import Foundation
import SuperLogKit
import LumiUI
import SwiftUI

// MARK: - 详情视图

/// 对话时间线详情视图（在 Popover 中显示）
public struct ConversationTimelineDetailView: View, SuperLog {
    public nonisolated static let emoji = "📅"
    public nonisolated static let verbose: Bool = true

    public let conversationId: UUID
    @EnvironmentObject private var chatHistoryVM: AppChatHistoryVM
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @State private var timelineItems: [MessageTimelineItem] = []
    private let timelineService = ConversationTimelineService()

    public var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "对话时间线", table: "ConversationTimeline"),
            systemImage: "timeline.selection",
            subtitle: summaryText
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                loadTimelineItems()
            }
            .help(String(localized: "刷新", table: "ConversationTimeline"))
        } content: {
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

    /// 获取当前模型的上下文窗口大小
    private var currentModelContextLimit: Int {
        let preference = conversationVM.getModelPreference(for: conversationId)
        return timelineService.contextLimit(
            providerId: preference?.providerId ?? llmVM.selectedProviderId,
            model: preference?.model ?? llmVM.currentModel,
            providers: llmVM.availableProviders
        )
    }

    /// 当前上下文窗口使用量（用于判断是否接近模型上限）
    private var currentContextTokens: Int {
        timelineService.currentContextTokens(from: timelineItems)
    }

    private var summaryText: String {
        let messageText = String(format: String(localized: "%lld messages", table: "ConversationTimeline"), timelineItems.count)
        guard currentContextTokens > 0 else {
            return messageText
        }

        let currentText = timelineService.formatToken(currentContextTokens)
        let contextText: String
        if currentModelContextLimit > 0 {
            let limitText = timelineService.formatToken(currentModelContextLimit)
            contextText = String(format: String(localized: "Context %@/%@", table: "ConversationTimeline"), currentText, limitText)
        } else {
            contextText = String(format: String(localized: "Context %@", table: "ConversationTimeline"), currentText)
        }
        return "\(messageText) · \(contextText)"
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
