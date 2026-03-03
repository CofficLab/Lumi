import SwiftUI
import MagicKit
import SwiftData
import OSLog

/// 对话列表视图
/// 使用 List 渲染会话列表，支持会话选择、删除和自动恢复上次选择的会话
struct ConversationListView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 数据上下文：用于查询和删除会话
    @Environment(\.modelContext) private var modelContext
    /// 智能体提供者：管理选中的会话
    @ObservedObject var agentProvider = AgentProvider.shared

    /// 会话列表：按更新时间倒序排列
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]

    /// 是否已恢复选择标记：防止重复恢复
    @State private var hasRestoredSelection = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ConversationListHeader()

            Divider()
                .background(Color.white.opacity(0.1))

            // 对话列表内容
            if conversations.isEmpty {
                ConversationListEmptyView()
            } else {
                conversationList
            }
        }
        .task {
            // 首次加载时恢复上次选择的会话
            if !hasRestoredSelection && !conversations.isEmpty {
                restoreSelectionIfNeeded()
                hasRestoredSelection = true
            }
        }
        .onChange(of: conversations.count) { oldCount, newCount in
            handleConversationListChange(oldCount: oldCount, newCount: newCount)
        }
    }
}

// MARK: - View

extension ConversationListView {
    /// 对话列表视图：渲染会话列表
    private var conversationList: some View {
        List(conversations, selection: $agentProvider.selectedConversationId) { conversation in
            ConversationItemView(
                conversation: conversation,
                onDelete: { handleDelete(conversation) }
            )
            .tag(conversation.id)
        }
    }
}

// MARK: - Action

extension ConversationListView {
    /// 恢复上次选择的会话
    /// 仅在首次加载且没有选中的会话时执行
    private func restoreSelectionIfNeeded() {
        // 如果已经有选中的会话，不需要恢复
        if agentProvider.selectedConversationId != nil {
            if Self.verbose {
                os_log("\(self.t)已有选中的会话，跳过恢复")
            }
            return
        }

        // 调用 AgentProvider 的恢复方法（会验证会话是否存在）
        agentProvider.restoreSelectedConversation(modelContext: modelContext)

        if let restoredId = agentProvider.selectedConversationId {
            os_log("\(self.t)✅ 已恢复会话选择：\(restoredId)")
        } else {
            if Self.verbose {
                os_log("\(self.t)ℹ️ 没有保存的会话选择")
            }
        }
    }

    /// 处理删除会话操作
    /// 删除后如果当前选中的是被删除的会话，自动切换到最新的会话
    /// - Parameter conversation: 要删除的会话
    private func handleDelete(_ conversation: Conversation) {
        os_log("\(self.t)🗑️ 开始删除对话：\(conversation.title)")

        // 如果删除的是当前选中的会话，且还有其他会话，自动切换到最新的
        if agentProvider.selectedConversationId == conversation.id {
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            if let nextConversation = remainingConversations.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    agentProvider.selectedConversationId = nextConversation.id
                    os_log("\(self.t)🔄 已自动切换到对话：\(nextConversation.title)")
                }
            } else {
                agentProvider.selectedConversationId = nil
                os_log("\(self.t)📭 没有剩余会话，已清空选中状态")
            }
        }

        // 使用当前视图的 modelContext 删除，确保 @Query 能检测到变化
        modelContext.delete(conversation)

        do {
            try modelContext.save()
            os_log("\(self.t)✅ 对话已删除：\(conversation.title)")
        } catch {
            os_log(.error, "\(self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - Event

extension ConversationListView {
    /// 处理会话列表数量变化的事件
    /// 当列表从空变为有数据时，自动恢复上次选择的会话
    /// - Parameters:
    ///   - oldCount: 变化前的会话数量
    ///   - newCount: 变化后的会话数量
    private func handleConversationListChange(oldCount: Int, newCount: Int) {
        // 如果列表从空变为有数据，恢复选择
        if oldCount == 0 && newCount > 0 && !hasRestoredSelection {
            restoreSelectionIfNeeded()
            hasRestoredSelection = true
        }
    }
}

// MARK: - Preview

#Preview("对话列表 - 标准尺寸") {
    ConversationListView()
        .frame(width: 300, height: 600)
}

#Preview("对话列表 - 窄屏") {
    ConversationListView()
        .frame(width: 250, height: 400)
}
