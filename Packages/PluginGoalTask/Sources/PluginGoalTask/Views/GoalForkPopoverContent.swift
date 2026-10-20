import LumiUI
import SwiftUI

/// 「在新对话中继续」的确认弹窗内容。
///
/// 与工具栏 popover(`GoalRowView.forkButton`)里「点了就跑」的单按钮不同,
/// 这里先把**将被带走的上下文**摊开给用户看:标题、描述、成功标准、未完成任务,
/// 用户确认后才真正执行 `forkAndStart`,避免误触导致源 Goal 被 `skipped`。
///
/// 视觉沿用 `GoalDescriptionPopoverContent` 的语言(同一套 header + 滚动正文 +
/// 底部确认按钮),因此两个入口在侧栏里的观感一致。
struct GoalForkPopoverContent: View {
    @LumiTheme private var theme

    let goal: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]
    let forkCoordinator: GoalForkCoordinator

    @State private var isForking = false
    @State private var errorMessage: String?

    /// 未完成(pending / inProgress)的任务,决定弹窗正文的重心。
    private var outstandingTasks: [GoalTaskDisplayItem] {
        tasks.filter { $0.status == .pending || $0.status == .inProgress }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .opacity(0.7)

            summary

            Divider()
                .opacity(0.7)

            footer
        }
        .frame(width: 340, height: 320)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.branch")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primary)
                .frame(width: 28, height: 28)
                .background(
                    theme.primary.opacity(0.12),
                    in: Circle()
                )

            Text(pluginLocalization.string("Continue in a new conversation"))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Summary

    /// 标题 + 描述 + 成功标准 + 未完成任务。
    ///
    /// 描述可能很长,整体放进 `ScrollView` 而非固定高度裁剪,保证长文本可完整阅读。
    @ViewBuilder
    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(GoalAccessibility.forkPopoverTitle)

                if let description = goal.goalDescription, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !outstandingTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pluginLocalization.string("Outstanding tasks"))
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)

                        ForEach(outstandingTasks) { task in
                            HStack(spacing: 6) {
                                Image(systemName: task.statusSystemImage)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(task.statusColor)
                                    .frame(width: 12)

                                Text(task.title)
                                    .font(.caption)
                                    .foregroundColor(theme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .accessibilityIdentifier(GoalAccessibility.forkPopoverTaskTitle)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.automatic)
    }

    // MARK: - Footer

    /// 底部确认区:确认按钮 + 失败原因。
    ///
    /// 错误就近展示而不是 toast / 关闭弹窗,原因是执行失败时源 Goal 可能已被
    /// 置为 `skipped`,用户需要看清原因再决定是否重试。
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer(minLength: 0)

                Button {
                    startFork()
                } label: {
                    Group {
                        if isForking {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Text(pluginLocalization.string("Continue in a new conversation"))
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isForking)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(GoalAccessibility.forkPopoverConfirm)

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func startFork() {
        guard !isForking else { return }
        errorMessage = nil
        isForking = true
        Task {
            defer { isForking = false }
            do {
                try await forkCoordinator.forkAndStart(goal: goal, tasks: tasks)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
