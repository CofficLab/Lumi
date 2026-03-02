import SwiftUI
import MagicKit
import SwiftData

/// 会话项视图
struct ConversationItemView: View {
    let conversation: Conversation
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 8) {
            // 标题和元信息
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(conversation.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // 时间戳和项目信息
                metadataSection
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
                onDelete()
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
    }
}
