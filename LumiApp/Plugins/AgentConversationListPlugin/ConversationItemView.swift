import MagicKit
import SwiftData
import SwiftUI

/// 会话项视图
/// 显示单个会话的标题、时间戳和项目信息，支持右键菜单删除操作
struct ConversationItemView: View {
    /// 会话模型：包含标题、更新时间、项目 ID 等信息
    let conversation: Conversation
    /// 删除回调：用户确认删除后调用
    let onDelete: () -> Void

    /// 是否显示删除确认对话框
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            // 标题和元信息
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(conversation.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // 时间戳和项目信息
                metadataSection
            }

            Spacer()
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
                onDelete()
            }
        } message: {
            Text("确定要删除对话「\(conversation.title)」吗？此操作将彻底删除该对话的所有消息，且无法恢复。")
        }
    }
}

// MARK: - View

extension ConversationItemView {
    /// 元数据区域：显示项目名称和相对时间
    /// 当会话关联了项目时显示项目名，否则只显示时间
    @ViewBuilder
    private var metadataSection: some View {
        HStack {
            if let projectId = conversation.projectId {
                let projectName = URL(fileURLWithPath: projectId).lastPathComponent
                Text(projectName)
                    .font(.system(size: 8))
                    .lineLimit(1)

                Text("•")
                    .font(.system(size: 6))
            }

            Text(conversation.updatedAt.formatted(.relative(presentation: .named)))
                .font(.system(size: 8))
        }
    }
}

// MARK: - Preview

#Preview("会话项 - 默认状态") {
    ConversationItemView(
        conversation: Conversation.example(),
        onDelete: { print("删除") }
    )
    .frame(width: 280)
    .padding()
}

#Preview("会话项 - 长标题") {
    ConversationItemView(
        conversation: Conversation.example(title: "这是一个非常长的会话标题，用于测试标题截断效果"),
        onDelete: { print("删除") }
    )
    .frame(width: 200)
    .padding()
}

// MARK: - Conversation+Preview

extension Conversation {
    /// 创建示例会话用于预览
    /// - Parameters:
    ///   - title: 标题，默认为"示例对话"
    ///   - projectId: 项目 ID，默认为示例项目路径
    ///   - minutesAgo: 多少分钟前更新，默认为 30
    /// - Returns: 示例会话实例
    static func example(
        title: String = "示例对话",
        projectId: String? = "/Users/example/project",
        minutesAgo: Int = 30
    ) -> Conversation {
        let item = Conversation()
        item.title = title
        item.projectId = projectId
        item.updatedAt = Date().addingTimeInterval(-Double(minutesAgo) * 60)
        return item
    }
}
