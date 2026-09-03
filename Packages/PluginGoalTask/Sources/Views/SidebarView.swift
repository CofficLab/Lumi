import KitSuperLog
import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: GoalVM

    @State private var isCollapsed = false

    private static let headerHeight: CGFloat = 44
    private static let maxTaskListHeight: CGFloat = 160

    /// 单个任务行高度(`TaskRowView` 内部消费此值计算行高)。
    static let rowHeight: CGFloat = 30

    /// 是否有可见的 Goal
    private var hasVisibleGoal: Bool {
        viewModel.hasActiveWork
    }

    init(viewModel: GoalVM) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if hasVisibleGoal {
                SidebarHeader(
                    activeGoal: viewModel.activeGoal,
                    progressText: viewModel.progressText,
                    isCollapsed: isCollapsed,
                    onToggleCollapsed: { isCollapsed.toggle() }
                )

                if isCollapsed {
                    EmptyView()
                } else if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.vertical, 8)
                } else {
                    blockedReasonView
                    taskListView
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: hasVisibleGoal ? sidebarHeight : 0)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minWidth: hasVisibleGoal ? 240 : 0, idealWidth: hasVisibleGoal ? 320 : 0)
        .overlay {
            if hasVisibleGoal {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LumiPluginLocalization.string("Goal & Tasks", bundle: .module))
    }

    // MARK: - Blocked Reason

    @ViewBuilder
    private var blockedReasonView: some View {
        if let goal = viewModel.activeGoal,
           goal.status == .blocked,
           let reason = goal.blockedReason {
            SidebarBlockedReason(reason: reason)
        }
    }

    // MARK: - Task List

    private var taskListView: some View {
        SidebarTaskList(tasks: viewModel.activeTasks)
            .frame(height: taskListHeight)
    }

    private var taskListHeight: CGFloat {
        guard !viewModel.activeTasks.isEmpty else { return 0 }
        let contentHeight = CGFloat(viewModel.activeTasks.count) * Self.rowHeight
            + CGFloat(max(0, viewModel.activeTasks.count - 1)) * 4
            + 8
        return min(contentHeight, Self.maxTaskListHeight)
    }

    private var sidebarHeight: CGFloat {
        guard hasVisibleGoal else { return 0 }
        if isCollapsed {
            return Self.headerHeight
        }
        if viewModel.isLoading {
            return Self.headerHeight + 32
        }
        var height = Self.headerHeight + taskListHeight
        // 阻塞原因最多占 2 行(caption2 ≈ 12pt,行高约 16pt)
        if viewModel.activeGoal?.status == .blocked,
           viewModel.activeGoal?.blockedReason != nil {
            height += 36
        }
        return height
    }
}
