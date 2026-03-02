import SwiftUI
import MagicKit
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.cofficlab.lumi", category: "ConversationList")

/// 对话列表视图 - 仅显示数据库中的对话列表
struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    
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
                conversationListView
            }
        }
        .padding(.vertical, 8)
        .background(DesignTokens.Material.glassThick)
        .task {
            // 调试：打印模型上下文和对话数量
            logger.info("🔍 modelContext: \(modelContext != nil ? "存在" : "不存在")")
            logger.info("📊 对话数量：\(conversations.count)")
            if !conversations.isEmpty {
                for conversation in conversations {
                    logger.info("  - \(conversation.title) (项目：\(conversation.projectId ?? "无"))")
                }
            }
        }
    }

    // MARK: - Conversation List View

    private var conversationListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(conversations) { conversation in
                    ConversationItemView(
                        conversation: conversation,
                        onDelete: handleDelete
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - Delete Handler
    
    /// 处理删除会话
    private func handleDelete(_ conversation: Conversation) {
        logger.info("🗑️ 开始删除对话：\(conversation.title)")
        
        // 如果当前选中的是要删除的会话，自动切换到其他会话
        if AgentProvider.shared.selectedConversationId == conversation.id {
            // 获取删除后的会话列表（排除当前要删除的）
            let remainingConversations = conversations.filter { $0.id != conversation.id }
            
            if let nextConversation = remainingConversations.first {
                // 自动选中列表中的第一个（最新的）会话
                AgentProvider.shared.selectConversation(nextConversation.id)
                logger.info("🔄 已自动切换到对话：\(nextConversation.title)")
            } else {
                // 没有剩余会话，清空选中状态
                AgentProvider.shared.selectedConversationId = nil
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
