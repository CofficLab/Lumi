import SwiftUI
import MagicKit
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.cofficlab.lumi", category: "ConversationList")

/// 对话列表视图 - 使用 List 渲染
struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var agentProvider = AgentProvider.shared
    
    @Query(sort: \Conversation.updatedAt, order: .reverse)
    private var conversations: [Conversation]
    
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
            logger.info("🔍 modelContext: \(modelContext != nil ? "存在" : "不存在")")
            logger.info("📊 对话数量：\(conversations.count)")
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
    }
    
    // MARK: - Delete Handler
    
    /// 处理删除会话
    private func handleDelete(_ conversation: Conversation) {
        logger.info("🗑️ 开始删除对话：\(conversation.title)")
        
        // 如果删除的是当前选中的会话，且还有其他会话，自动切换到最新的
        if agentProvider.selectedConversationId == conversation.id {
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            if let nextConversation = remainingConversations.first {
                // 延迟一点执行，确保删除完成后再选中
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    agentProvider.selectedConversationId = nextConversation.id
                    logger.info("🔄 已自动切换到对话：\(nextConversation.title)")
                }
            } else {
                agentProvider.selectedConversationId = nil
                logger.info("📭 没有剩余会话，已清空选中状态")
            }
        }
        
        // 使用当前视图的 modelContext 删除，确保 @Query 能检测到变化
        modelContext.delete(conversation)
        
        do {
            try modelContext.save()
            logger.info("✅ 对话已删除：\(conversation.title)")
        } catch {
            logger.error("❌ 删除对话失败：\(error.localizedDescription)")
        }
    }
}
