import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI

/// 对话行
///
/// 显示单个对话的标题、时间戳、模型信息和项目信息。
/// 支持处理中动画、近期活跃指示器和删除确认。
struct ConversationRow: View, SuperLog {
    nonisolated public static let emoji = "🗨️"
    nonisolated public static let verbose: Bool = true

    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let conversation: LumiConversationSummary
    let isProcessing: Bool
    let llmProvider: (any LLMProviderManaging)?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    /// 近期活跃时间窗口，默认 5 分钟
    private var recentActivityWindow: TimeInterval { 5 * 60 }

    /// 是否在近期活跃时间窗口内有更新
    private var isRecentlyActive: Bool {
        Date().timeIntervalSince(conversation.updatedAt) < recentActivityWindow && !isProcessing
    }

    /// 删除确认弹窗状态
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            // 对话图标（活跃状态有不同表现）
            iconView

            // 标题和元信息
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title.isEmpty ? LumiPluginLocalization.string("Untitled", bundle: .module) : conversation.title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(isProcessing ? theme.primary : theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // 时间戳和模型信息
                metadataSection
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(LumiPluginLocalization.string("Delete Conversation", bundle: .module), systemImage: "trash")
            }
        }
        .alert(LumiPluginLocalization.string("Delete Conversation", bundle: .module), isPresented: $showDeleteConfirmation) {
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) { }
            Button(LumiPluginLocalization.string("Delete", bundle: .module), role: .destructive) {
                onDelete()
            }
        } message: {
            let format = LumiPluginLocalization.string("Are you sure you want to delete \"%@\"? This will permanently remove all messages and cannot be undone.", bundle: .module)
            Text(String(format: format, conversation.title.isEmpty ? LumiPluginLocalization.string("Untitled", bundle: .module) : conversation.title))
        }
    }

    // MARK: - Subviews

    /// 图标视图：包含图标、处理中脉冲动画、近期活跃指示器
    private var iconView: some View {
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

            if isRecentlyActive {
                RecentActivityIndicator(color: theme.primary)
            }
        }
        .frame(width: 24, height: 24)
    }

    /// 元数据区域：显示模型信息、项目名称和相对时间
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

    // MARK: - Private

    /// 量化的相对时间展示：减少 UI 因秒级波动导致的频繁跳变
    /// - 1分钟内：按 10 秒分桶（0-9秒显示"刚刚"，10-19秒显示"10秒前"，以此类推）
    /// - 1分钟以上：按分钟显示（比如"1分钟前"）
    private func coarseRelativeTime(from date: Date, now: Date = Date()) -> String {
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

// MARK: - Recent Activity Indicator

/// 近期活跃小圆点指示器
private struct RecentActivityIndicator: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .offset(x: 4, y: -4)
    }
}

// MARK: - Convenience Init

extension ConversationRow {
    /// 不带处理状态的初始化器
    init(
        conversation: LumiConversationSummary,
        llmProvider: (any LLMProviderManaging)?,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.init(
            conversation: conversation,
            isProcessing: false,
            llmProvider: llmProvider,
            isSelected: isSelected,
            onSelect: onSelect,
            onDelete: onDelete
        )
    }
}
