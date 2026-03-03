import SwiftUI
import MagicKit
import SwiftData
import OSLog

/// 对话列表视图 - 使用 List 渲染
struct ConversationListView: View, SuperLog {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var agentProvider = AgentProvider.shared
    
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]
    
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
        .padding(.vertical, 8)
        .background(DesignTokens.Material.glassThick)
        .task {
            if Self.verbose {
                os_log("\(Self.t)对话数量：\(conversations.count)")
            }
            
            // 首次加载时恢复上次选择的会话
            if !hasRestoredSelection && !conversations.isEmpty {
                restoreSelectionIfNeeded()
                hasRestoredSelection = true
            }
        }
        .onChange(of: conversations.count) { oldCount, newCount in
            // 如果列表从空变为有数据，恢复选择
            if oldCount == 0 && newCount > 0 && !hasRestoredSelection {
                restoreSelectionIfNeeded()
                hasRestoredSelection = true
            }
        }
    }

    // MARK: - Restore Selection

    /// 恢复上次选择的会话
    private func restoreSelectionIfNeeded() {
        // 如果已经有选中的会话，不需要恢复
        if agentProvider.selectedConversationId != nil {
            if Self.verbose {
                os_log("\(Self.t)已有选中的会话，跳过恢复")
            }
            return
        }
        
        // 调用 AgentProvider 的恢复方法（会验证会话是否存在）
        agentProvider.restoreSelectedConversation(modelContext: modelContext)
        
        if let restoredId = agentProvider.selectedConversationId {
            os_log("\(Self.t)✅ 已恢复会话选择：\(restoredId)")
        } else {
            if Self.verbose {
                os_log("\(Self.t)ℹ️ 没有保存的会话选择")
            }
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List(conversations, selection: $agentProvider.selectedConversationId) { conversation in
            ConversationItemView(
                conversation: conversation,
                onDelete: { handleDelete(conversation) }
            )
            .tag(conversation.id)
        }
        .scrollIndicators(.hidden)
        .listStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
    }
    
    // MARK: - Delete Handler
    
    /// 处理删除会话
    private func handleDelete(_ conversation: Conversation) {
        os_log("\(Self.t)🗑️ 开始删除对话：\(conversation.title)")
        
        // 如果删除的是当前选中的会话，且还有其他会话，自动切换到最新的
        if agentProvider.selectedConversationId == conversation.id {
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            if let nextConversation = remainingConversations.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    agentProvider.selectedConversationId = nextConversation.id
                    os_log("\(Self.t)🔄 已自动切换到对话：\(nextConversation.title)")
                }
            } else {
                agentProvider.selectedConversationId = nil
                os_log("\(Self.t)📭 没有剩余会话，已清空选中状态")
            }
        }
        
        // 使用当前视图的 modelContext 删除，确保 @Query 能检测到变化
        modelContext.delete(conversation)
        
        do {
            try modelContext.save()
            os_log("\(Self.t)✅ 对话已删除：\(conversation.title)")
        } catch {
            os_log(.error, "\(Self.t)❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}
