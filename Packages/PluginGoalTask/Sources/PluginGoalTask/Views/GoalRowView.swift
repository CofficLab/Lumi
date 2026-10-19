import LumiLocalizationKit
import LumiUI
import SwiftUI

/// 工具栏弹窗中的单个 Goal 行(可展开查看任务)。
///
/// 头部展示状态图标 + 标题 + 完成度 + 折叠箭头,点击切换展开;
/// 进度条基于「已完成 / 总数」计算;展开后展示任务列表与可选的阻塞原因。
/// 自身只持有展开状态(`isExpanded`),选中/刷新等行为委托父组件。
struct GoalRowView: View {
    @LumiTheme private var theme
    let item: GoalListItem
    /// 为 `nil` 时隐藏「在新对话中继续」按钮（宿主缺少必需的 Provider）。
    let forkCoordinator: GoalForkCoordinator?

    @State private var isExpanded = false
    @State private var isForking = false
    @State private var forkErrorMessage: String?

    private var goal: GoalDisplayItem { item.goal }
    private var tasks: [GoalTaskDisplayItem] { item.tasks }

    /// 仅活跃 Goal 可继续推进；终态 Goal 没有未完成的上下文。
    private var canFork: Bool {
        !goal.isTerminal && forkCoordinator != nil
    }

    private var completedCount: Int {
        tasks.filter { $0.status == .completed || $0.status == .skipped }.count
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private var statusColor: Color {
        goal.statusColor
    }

    private var statusIcon: String {
        goal.statusSystemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            goalHeader
            progressBar
            blockedReasonRow
            forkErrorRow
            expandedTaskList
        }
        .padding(8)
        .background(theme.textPrimary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Subviews

    /// Goal 头部(点击展开/折叠任务)
    private var goalHeader: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 14)

                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Text("\(completedCount)/\(tasks.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 与展开按钮并列，避免整行被 fork 按钮吞掉点击区域。
            if canFork {
                forkButton
            }
        }
    }

    /// 「在新对话中继续」按钮：复制 Goal 到新对话并立即开跑。
    private var forkButton: some View {
        Button {
            forkErrorMessage = nil
            guard let forkCoordinator else { return }
            isForking = true
            Task {
                defer { isForking = false }
                do {
                    try await forkCoordinator.forkAndStart(goal: goal, tasks: tasks)
                } catch {
                    forkErrorMessage = error.localizedDescription
                }
            }
        } label: {
            Group {
                if isForking {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.branch")
                }
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isForking)
        .help(pluginLocalization.string("Continue in a new conversation"))
    }

    /// fork 失败时的错误提示（就近展示，避免弹窗一闪而过）。
    @ViewBuilder
    private var forkErrorRow: some View {
        if let forkErrorMessage {
            Text(forkErrorMessage)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    /// 进度条:已用 statusColor 填充,背景为半透明灰。
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor)
                    .frame(width: geometry.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }

    /// 仅当 Goal 处于 blocked 且有 reason 时展示。
    @ViewBuilder
    private var blockedReasonRow: some View {
        if let blockedReason = goal.blockedReason, goal.status == .blocked {
            Text(String(format: pluginLocalization.string("⚠️ %@"), blockedReason))
                .font(.caption2)
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
    }

    /// 展开后的任务列表。
    @ViewBuilder
    private var expandedTaskList: some View {
        if isExpanded && !tasks.isEmpty {
            Divider()

            ForEach(tasks) { task in
                HStack(spacing: 6) {
                    Image(systemName: task.statusSystemImage)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(task.statusColor)
                        .frame(width: 12)

                    Text(task.title)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()
                }
            }
        }
    }
}