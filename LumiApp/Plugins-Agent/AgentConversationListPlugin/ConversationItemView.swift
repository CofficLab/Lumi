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
                Label(String(localized: "Delete Conversation", table: "ConversationList"), systemImage: "trash")
            }
        }
        .alert(String(localized: "Delete Conversation", table: "ConversationList"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Cancel", table: "ConversationList"), role: .cancel) { }
            Button(String(localized: "Delete", table: "ConversationList"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text(String(localized: "Are you sure you want to delete \"%@\"? This will permanently remove all messages and cannot be undone.", table: "ConversationList"), conversation.title)
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

            Text(coarseRelativeTime(from: conversation.updatedAt))
                .font(.system(size: 8))
        }
    }
}

// MARK: - Private

private extension ConversationItemView {
    /// 量化的相对时间展示：减少 UI 因秒级波动导致的频繁跳变
    /// - 1分钟内：按 10 秒分桶（0-9秒显示"刚刚"，10-19秒显示"10秒前"，以此类推）
    /// - 1分钟以上：按分钟显示（比如"1分钟前"）
    func coarseRelativeTime(from date: Date, now: Date = Date()) -> String {
        let delta = now.timeIntervalSince(date)
        guard delta >= 0 else { return String(localized: "Just now", table: "ConversationList") }

        let seconds = Int(delta)
        if seconds < 60 {
            let bucket = (seconds / 10) * 10
            if bucket <= 0 {
                return String(localized: "Just now", table: "ConversationList")
            }
            return String(localized: "%d seconds ago", table: "ConversationList", bucket)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return String(localized: "%d minutes ago", table: "ConversationList", minutes)
        }

        let hours = minutes / 60
        if hours < 24 {
            return String(localized: "%d hours ago", table: "ConversationList", hours)
        }

        let days = hours / 24
        return String(localized: "%d days ago", table: "ConversationList", days)
    }
}

// MARK: - Preview

#Preview("会话项 - 默认状态") {
    ConversationItemView(
        conversation: Conversation.example(),
        onDelete: { ConversationListPlugin.logger.info("\(ConversationListPlugin.t)删除") }
    )
    .frame(width: 280)
    .padding()
}

#Preview("会话项 - 长标题") {
    ConversationItemView(
        conversation: Conversation.example(title: "这是一个非常长的会话标题，用于测试标题截断效果"),
        onDelete: { ConversationListPlugin.logger.info("\(ConversationListPlugin.t)删除") }
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