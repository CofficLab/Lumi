import LumiLoggingKit
import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: GoalVM

    /// 「在新对话中继续」的编排器,为 `nil` 时隐藏该入口(宿主缺少必需的 Provider)。
    let forkCoordinator: GoalForkCoordinator?

    @State private var isCollapsed = false

    private static let headerHeight: CGFloat = 44
    private static let maxTaskListHeight: CGFloat = 160

    /// 单个任务行高度(`TaskRowView` 内部消费此值计算行高)。
    static let rowHeight: CGFloat = 30

    /// 阻塞原因卡片高度(2 行 `caption2` + 上下内边距),由 `SidebarBlockedReason` 消费。
    static let blockedReasonCardHeight: CGFloat = 40

    /// 任务列表容器与侧边栏底边之间的留白。
    ///
    /// 任务列表是容器内最后一个元素,没有下方的兄弟视图撑开间距,
    /// 直接贴住底边会显得拥挤,这里留一段固定底部内边距。
    private static let taskListBottomInset: CGFloat = 10

    /// 是否有可见的 Goal
    private var hasVisibleGoal: Bool {
        viewModel.hasActiveWork
    }

    /// 是否需要展示阻塞原因卡片(与 `blockedReasonView` 的条件保持一致)。
    private var showsBlockedReason: Bool {
        viewModel.activeGoal?.status == .blocked
            && viewModel.activeGoal?.blockedReason != nil
    }

    init(viewModel: GoalVM, forkCoordinator: GoalForkCoordinator? = nil) {
        self.viewModel = viewModel
        self.forkCoordinator = forkCoordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            if hasVisibleGoal {
                SidebarHeader(
                    activeGoal: viewModel.activeGoal,
                    progressText: viewModel.progressText,
                    isCollapsed: isCollapsed,
                    forkCoordinator: forkCoordinator,
                    tasks: viewModel.activeTasks,
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
                    blockedReasonDivider
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
        .accessibilityLabel(pluginLocalization.string("Goal & Tasks"))
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

    /// 阻塞原因卡片与任务列表之间的分割线。
    ///
    /// 仅在阻塞原因卡片实际渲染时出现,与 `showsBlockedReason` 条件一致。
    @ViewBuilder
    private var blockedReasonDivider: some View {
        if showsBlockedReason {
            Rectangle()
                .fill(Color.orange.opacity(0.16))
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
    }

    // MARK: - Task List

    private var taskListView: some View {
        SidebarTaskList(tasks: viewModel.activeTasks)
            .frame(height: taskListHeight)
            // 列表容器贴住侧边栏底边会显得拥挤,与上方元素之间留出呼吸感。
            .padding(.bottom, Self.taskListBottomInset)
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
        // 任务列表与底边之间的留白(仅在列表实际渲染时存在)。
        if !viewModel.activeTasks.isEmpty {
            height += Self.taskListBottomInset
        }
        // 阻塞原因卡片 + 卡片与任务列表之间的分割线
        if showsBlockedReason {
            height += Self.blockedReasonCardHeight + 1
        }
        return height
    }
}
