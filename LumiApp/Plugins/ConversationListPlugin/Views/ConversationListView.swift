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
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // 对话列表内容
            if conversations.isEmpty {
                emptyView
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

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "message.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text("对话历史")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Conversation List View

    private var conversationListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(conversations) { conversation in
                    ConversationItemView(conversation: conversation)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("暂无对话")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Conversation Item View

struct ConversationItemView: View {
    let conversation: Conversation
    
    @ObservedObject var agentProvider = AgentProvider.shared
    
    var isSelected: Bool {
        agentProvider.selectedConversationId == conversation.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 图标
                Image(systemName: isSelected ? "message.fill" : "message")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .accentColor : DesignTokens.Color.semantic.textSecondary)
                    .frame(width: 14)
                
                // 标题
                Text(conversation.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .accentColor : DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            
            // 时间戳和项目信息
            HStack {
                if let projectId = conversation.projectId {
                    let projectName = URL(fileURLWithPath: projectId).lastPathComponent
                    Text(projectName)
                        .font(.system(size: 8))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.system(size: 6))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
                
                Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .onTapGesture {
            agentProvider.selectConversation(conversation.id)
        }
    }
}

#Preview {
    ConversationListView()
        .frame(width: 220, height: 400)
        .modelContainer(for: [Conversation.self, ChatMessageEntity.self])
        .inRootView()
}
