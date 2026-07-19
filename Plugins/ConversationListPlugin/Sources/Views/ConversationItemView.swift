import LumiUI
import SuperLogKit
import LumiKernel
import SwiftUI

/// 会话项视图
/// 显示单个会话的标题、时间戳和项目信息，支持右键菜单删除操作
///
/// ## 活跃状态
///
/// 对话项支持两种活跃状态：
/// - **处理中**：对话正在处理消息，图标会显示脉冲涟漪动画和主题色
/// - **近期活跃**：对话在最近 `recentActivityWindow` 时间内有更新，图标显示圆点指示器
public struct ConversationItemView: View, SuperLog {
    public nonisolated static let emoji = "🗨️"
    public nonisolated static let verbose: Bool = true

    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 会话模型：包含标题、更新时间、项目 ID 等信息
    public let conversation: ConversationListItem
    /// 删除回调：用户确认删除后调用
    public let onDelete: () -> Void

    /// 对话是否正在处理消息（由 ConversationListContext 驱动）
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
                    .overlay {
                        if isProcessing {
                            PulseRipple(color: theme.primary)
                        }
                    }

                if !isProcessing, isRecentlyActive {
                    // 近期活跃：小圆点
                    RecentActivityIndicator(color: theme.primary)
                }
            }

            // 标题和元信息
            VStack(alignment: .leading, spacing: 4) {
                // 标题
                Text(conversation.displayTitle)
                    .font(.appMicroEmphasized)
                    .foregroundColor(isProcessing ? theme.primary : theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // 时间戳和项目信息
                metadataSection
            }

            Spacer()
        }
        .contextMenu {
            Button(role: .destructive) {
                if Self.verbose, ConversationListPlugin.verbose {
                    ConversationListPlugin.logger.info("\(Self.t)🖱️ 右键菜单唤起：用户点击 Delete - \(conversation.displayTitle)")
                }
                showDeleteConfirmation = true
            } label: {
                Label(LumiPluginLocalization.string("Delete Conversation", bundle: .module), systemImage: "trash")
            }
        }
        .alert(LumiPluginLocalization.string("Delete Conversation", bundle: .module), isPresented: $showDeleteConfirmation) {
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) { }
            Button(LumiPluginLocalization.string("Delete", bundle: .module), role: .destructive) {
                if Self.verbose && ConversationListPlugin.verbose {
                    ConversationListPlugin.logger.info("\(Self.t)✅ Alert 确认：用户点击 Delete - \(conversation.displayTitle)")
                }
                onDelete()
            }
        } message: {
            let format = LumiPluginLocalization.string("Are you sure you want to delete \"%@\"? This will permanently remove all messages and cannot be undone.", bundle: .module)
            Text(String(format: format, conversation.displayTitle))
        }
    }
}

// MARK: - Activity Indicators

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
    /// 元数据区域：显示模型信息、项目名称和相对时间
    /// 当会话关联了模型时显示供应商/模型，关联了项目时显示项目名
    @ViewBuilder
    private var metadataSection: some View {
        HStack {
            // 模型信息
            if let modelName = conversation.modelName, !modelName.isEmpty {
                if let providerID = conversation.providerID, !providerID.isEmpty {
                    Text("\(providerID)/\(modelName)")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(modelName)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }

                Text(verbatim: LumiPluginLocalization.string("•", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }

            // 项目信息
            if let projectPath = conversation.projectPath {
                let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
                Text(projectName)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)

                Text(verbatim: LumiPluginLocalization.string("•", bundle: .module))
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

extension ConversationItemView {
    /// 量化的相对时间展示：减少 UI 因秒级波动导致的频繁跳变
    /// - 1分钟内：按 10 秒分桶（0-9秒显示"刚刚"，10-19秒显示"10秒前"，以此类推）
    /// - 1分钟以上：按分钟显示（比如"1分钟前"）
    public func coarseRelativeTime(from date: Date, now: Date = Date()) -> String {
        let delta = now.timeIntervalSince(date)
        guard delta >= 0 else { return LumiPluginLocalization.string("Just now", bundle: .module) }

        let seconds = Int(delta)
        if seconds < 60 {
            let bucket = (seconds / 10) * 10
            if bucket <= 0 {
                return LumiPluginLocalization.string("Just now", bundle: .module)
            }
            let format = LumiPluginLocalization.string("%d seconds ago", bundle: .module)
            return String(format: format, bucket)
        }

        let minutes = seconds / 60
        if minutes < 60 {
            let format = LumiPluginLocalization.string("%d minutes ago", bundle: .module)
            return String(format: format, minutes)
        }

        let hours = minutes / 60
        if hours < 24 {
            let format = LumiPluginLocalization.string("%d hours ago", bundle: .module)
            return String(format: format, hours)
        }

        let days = hours / 24
        let format = LumiPluginLocalization.string("%d days ago", bundle: .module)
        return String(format: format, days)
    }
}

// MARK: - Preview

#Preview("会话项 - 默认状态") {
    ConversationItemView(
        conversation: ConversationListItem.example(),
        onDelete: { if ConversationListPlugin.verbose { ConversationListPlugin.logger.info("\(ConversationListPlugin.t)删除") } }
    )
    .frame(width: 200)
    .padding()
}

#Preview("会话项 - 处理中") {
    ConversationItemView(
        conversation: ConversationListItem.example(),
        onDelete: {},
        isProcessing: true
    )
    .frame(width: 200)
    .padding()
}

#Preview("会话项 - 近期活跃") {
    ConversationItemView(
        conversation: ConversationListItem.example(minutesAgo: 2),
        onDelete: {}
    )
    .frame(width: 200)
    .padding()
}

#Preview("会话项 - 无模型信息") {
    ConversationItemView(
        conversation: ConversationListItem.example(providerID: nil, modelName: nil),
        onDelete: {}
    )
    .frame(width: 200)
    .padding()
}

// MARK: - ConversationListItem+Preview

extension ConversationListItem {
    /// 创建示例会话用于预览。
    public static func example(
        title: String = "示例对话",
        projectPath: String? = "/Users/example/project",
        minutesAgo: Int = 30,
        providerID: String? = "anthropic",
        modelName: String? = "claude-sonnet-4-20250514"
    ) -> ConversationListItem {
        ConversationListItem(
            id: UUID(),
            projectPath: projectPath,
            title: title,
            createdAt: Date().addingTimeInterval(-Double(minutesAgo + 30) * 60),
            updatedAt: Date().addingTimeInterval(-Double(minutesAgo) * 60),
            providerID: providerID,
            modelName: modelName
        )
    }
}
