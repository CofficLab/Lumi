import LumiUI
import SwiftUI

/// SidebarView 顶部状态行。
///
/// 展示当前活跃 Goal 的图标/标题/进度文本,并提供描述弹窗、在新对话中继续、
/// 折叠三个操作入口。所有回调由 `SidebarView` 注入,本组件不持有状态机。
struct SidebarHeader: View {
    @LumiTheme private var theme

    @State private var showDescriptionPopover = false
    @State private var showForkPopover = false

    let activeGoal: GoalDisplayItem?
    let progressText: String
    let isCollapsed: Bool

    /// 为 `nil` 表示宿主缺少必需的 Provider,此时隐藏「在新对话中继续」入口。
    let forkCoordinator: GoalForkCoordinator?
    /// 当前活跃 Goal 的任务,用于 fork 弹窗预览未完成项。
    let tasks: [GoalTaskDisplayItem]

    let onToggleCollapsed: () -> Void

    /// 仅活跃 Goal 可继续推进;终态 Goal 没有未完成的上下文。
    private var canFork: Bool {
        guard let goal = activeGoal else { return false }
        return !goal.isTerminal && forkCoordinator != nil
    }

    var body: some View {
        HStack(spacing: 6) {
            titleView

            Spacer()

            if activeGoal != nil {
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(GoalAccessibility.goalProgress)
            }

            descriptionButton
            forkButton
            collapseButton
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var titleView: some View {
        if let goal = activeGoal {
            HStack(spacing: 6) {
                Image(systemName: goal.statusSystemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(goal.statusColor)
                    .frame(width: 16)

                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier(GoalAccessibility.goalTitle)
            }
        } else {
            Label(
                pluginLocalization.string("Goal"),
                systemImage: "target"
            )
            .font(.headline)
            .accessibilityIdentifier(GoalAccessibility.goalTitlePlaceholder)
        }
    }

    @ViewBuilder
    private var descriptionButton: some View {
        if let description = activeGoal?.goalDescription,
           !description.isEmpty {
            Button {
                showDescriptionPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(showDescriptionPopover ? theme.primary : theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        showDescriptionPopover
                            ? theme.primary.opacity(0.12)
                            : theme.textPrimary.opacity(0.06),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .help(pluginLocalization.string("Goal description"))
            .accessibilityLabel(pluginLocalization.string("Goal description"))
            .accessibilityIdentifier(GoalAccessibility.descriptionButton)
            .popover(isPresented: $showDescriptionPopover, arrowEdge: .bottom) {
                GoalDescriptionPopoverContent(text: description)
            }
        }
    }

    /// 「在新对话中继续」按钮:把当前 Goal 复制到新对话并开跑。
    ///
    /// 视觉与 info 按钮对齐(同尺寸圆形底 + `.plain`),位置紧随其后。
    /// 终态 Goal 或缺少 `MessageSendingProviding` 时整体隐藏。
    @ViewBuilder
    private var forkButton: some View {
        if let goal = activeGoal, let forkCoordinator, canFork {
            Button {
                showForkPopover.toggle()
            } label: {
                Image(systemName: "arrow.branch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(showForkPopover ? theme.primary : theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        showForkPopover
                            ? theme.primary.opacity(0.12)
                            : theme.textPrimary.opacity(0.06),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .help(pluginLocalization.string("Continue in a new conversation"))
            .accessibilityLabel(pluginLocalization.string("Continue in a new conversation"))
            .accessibilityIdentifier(GoalAccessibility.forkButton)
            .popover(isPresented: $showForkPopover, arrowEdge: .bottom) {
                GoalForkPopoverContent(
                    goal: goal,
                    tasks: tasks,
                    forkCoordinator: forkCoordinator
                )
            }
        }
    }

    private var collapseButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                onToggleCollapsed()
            }
        } label: {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .help(pluginLocalization.string(isCollapsed ? "Expand" : "Collapse"))
        .accessibilityIdentifier(GoalAccessibility.collapseButton)
    }
}
