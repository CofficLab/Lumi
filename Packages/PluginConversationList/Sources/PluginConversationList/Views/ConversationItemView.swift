import LumiUI
import SwiftData
import SwiftUI

/// 会话项视图
/// 显示单个会话的标题、时间戳和项目信息，支持右键菜单删除操作
///
/// ## 活跃状态
///
/// 对话项支持两种活跃状态：
/// - **处理中**：对话正在处理消息，图标会显示脉冲动画和主题色
/// - **近期活跃**：对话在最近 `recentActivityWindow` 时间内有更新，图标显示圆点指示器
public struct ConversationItemView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 会话模型：包含标题、更新时间、项目 ID 等信息
    public let conversation: Conversation
    /// 删除回调：用户确认删除后调用
    public let onDelete: () -> Void

    /// 对话是否正在处理消息（由 WindowConversationStatusVM 驱动）
    public var isProcessing: Bool = false

    /// 近期活跃时间窗口，默认 5 分钟
    public var recentActivityWindow: TimeInterval = 5 * 60

    /// 是否显示删除确认对话框
    @State private var showDeleteConfirmation = false

    /// 计算：对话是否在近期活跃时间窗口内有更新
    private var isRecentlyActive: Bool {
        Date().timeIntervalSince(conversation.updatedAt) < recentActivityWindow
    }

    public var body: some View {
        HStack(spacing: 8) {
            // 对话图标（活跃状态有不同表现）
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.appMicro)
                    .foregroundColor(isProcessing ? theme.primary : theme.textTertiary)
                    .padding(3)

                if isProcessing {
                    // 处理中：脉冲动画
                    ProcessingPulseIndicator(color: theme.primary)
                } else if isRecentlyActive {
                    // 近期活跃：小圆点
                    RecentActivityIndicator(color: theme.primary)
                }
            }

            // 标题和元信息
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(conversation.displayTitle)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
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
            let format = String(localized: "Are you sure you want to delete \"%@\"? This will permanently remove all messages and cannot be undone.", table: "ConversationList")
            Text(String(format: format, conversation.displayTitle))
        }
    }
}

// MARK: - Activity Indicators

/// 处理中脉冲动画指示器
private struct ProcessingPulseIndicator: View {
    public let color: Color
    @State private var isAnimating = false

    public var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 12, height: 12)
            .scaleEffect(isAnimating ? 1.8 : 1.0)
            .opacity(isAnimating ? 0 : 0.5)
            .animation(
                .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

/// 近期活跃小圆点指示器
private struct RecentActivityIndicator: View {
    public let color: Color

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(x: 4, y: -4)
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
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)

                Text("•")
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            Text(coarseRelativeTime(from: conversation.updatedAt))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Private

private extension ConversationItemView {
    /// 量化的相对时间展示：减少 UI 因秒级波动导致的频繁跳变
    /// - 1分钟内：按 10 秒分桶（0-9秒显示"刚刚"，10-19秒显示"10秒前"，以此类推）
    /// - 1分钟以上：按分钟显示（比如"1分钟前"）
    public func coarseRelativeTime(from date: Date, now: Date = Date()) -> String {
        let delta = now.timeIntervalSince(date)
        guard delta >= 0 else { return String(localized: "Just now", table: "ConversationList") }

        let seconds = Int(delta)
        if seconds < 60 {
            let bucket = (seconds / 10) * 10
            if bucket <= 0 {
                return String(localized: "Just now", table: "ConversationList")
            }
            let format = String(localized: "%d seconds ago", table: "ConversationList")
            return String(format: format, bucket)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            let format = String(localized: "%d minutes ago", table: "ConversationList")
            return String(format: format, minutes)
        }

        let hours = minutes / 60
        if hours < 24 {
            let format = String(localized: "%d hours ago", table: "ConversationList")
            return String(format: format, hours)
        }

        let days = hours / 24
        let format = String(localized: "%d days ago", table: "ConversationList")
        return String(format: format, days)
    }
}

// MARK: - Preview

#Preview("会话项 - 默认状态") {
    ConversationItemView(
        conversation: Conversation.example(),
        onDelete: { if ConversationListPlugin.verbose { ConversationListPlugin.logger.info("\(ConversationListPlugin.t)删除") } }
    )
    .frame(width: 200)
    .padding()
}

#Preview("会话项 - 处理中") {
    ConversationItemView(
        conversation: Conversation.example(),
        onDelete: {},
        isProcessing: true
    )
    .frame(width: 200)
    .padding()
}

#Preview("会话项 - 近期活跃") {
    ConversationItemView(
        conversation: Conversation.example(minutesAgo: 2),
        onDelete: {}
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
    public static func example(
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
