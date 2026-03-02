import SwiftUI
import MagicKit
import SwiftData

/// 会话项视图
struct ConversationItemView: View {
    let conversation: Conversation
    let onDelete: (Conversation) -> Void
    
    @ObservedObject var agentProvider = AgentProvider.shared
    @State private var showDeleteConfirmation = false
    
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
            metadataSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            agentProvider.selectConversation(conversation.id)
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("删除对话", systemImage: "trash")
            }
        }
        .alert("删除对话", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onDelete(conversation)
            }
        } message: {
            Text("确定要删除对话「\(conversation.title)」吗？此操作将彻底删除该对话的所有消息，且无法恢复。")
        }
    }
    
    // MARK: - Metadata Section
    
    @ViewBuilder
    private var metadataSection: some View {
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
}
