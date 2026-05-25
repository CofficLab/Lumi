import LumiUI
import SwiftUI
import Foundation

/// 对话时间线状态栏视图
struct ConversationTimelineView: View, SuperLog {
    nonisolated static let emoji = "📅"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var chatHistoryVM: AppChatHistoryVM
    @EnvironmentObject private var llmVM: AppLLMVM
    @State private var messageCount: Int = 0
    @State private var currentContextTokens: Int = 0
    @State private var refreshTask: Task<Void, Never>?
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
                            .font(.appMicroEmphasized)

                        Text("\(messageCount)")
                            .font(.appMicro)

                        if currentContextTokens > 0 {
                            Divider().frame(height: 12)
                            Text(contextTokenLabel)
                                .font(.appMicro)
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
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            refreshMessageCount()
        }
        .onMessageSaved { message, conversationId in
            // 只刷新当前选中对话的消息
            guard conversationId == conversationVM.selectedConversationId else { return }
            scheduleMessageCountRefresh(for: conversationId)
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
        let preference = conversationVM.getModelPreference()
        return timelineService.contextLimit(
            providerId: preference?.providerId ?? llmVM.selectedProviderId,
            model: preference?.model ?? llmVM.currentModel,
            providers: llmVM.availableProviders
        )
    }

    /// 刷新消息数量和当前上下文 token 数
    private func refreshMessageCount() {
        refreshTask?.cancel()
        refreshTask = nil

        guard let conversationId = conversationVM.selectedConversationId else {
            messageCount = 0
            currentContextTokens = 0
            return
        }

        let summary = chatHistoryVM.getConversationTimelineSummary(forConversationId: conversationId)
        messageCount = summary.messageCount
        currentContextTokens = summary.currentContextTokens
    }

    /// 合并高频消息保存事件，避免流式输出期间反复触发主线程数据库查询。
    private func scheduleMessageCountRefresh(for conversationId: UUID) {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard conversationVM.selectedConversationId == conversationId else { return }
                if Self.verbose {
                    AppLogger.core.info("\(Self.t)📬 刷新统计")
                }
                refreshMessageCount()
            }
        }
    }
}
