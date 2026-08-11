import SwiftUI
import SuperLogKit
import LumiKernel

/// 右侧栏视图 - 展示当前会话的单一活跃 Goal 及其 Tasks
///
/// 容器职责:状态机、生命周期、与 `GoalStateManager` 的数据绑定,
/// 以及整体尺寸/背景/边框。子组件拆分至:
/// - `SidebarHeader`:顶部状态行 + 折叠/刷新/描述按钮
/// - `SidebarTaskList` / `TaskRowView`:任务列表与单行渲染
/// - `SidebarBlockedReason`:阻塞原因提示
/// - `GoalDescriptionPopoverContent`:描述长文本弹窗
///
/// 相关展示模型位于 `Models/` 目录(`GoalDisplayItem` /
/// `GoalTaskDisplayItem` / `NotificationObserverHolder`)。
public struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @State private var isCollapsed = false

    /// 获取当前会话 ID 的闭包(内部统一为 String?)
    private let conversationIdProvider: () -> String?

    /// 获取背景色的闭包
    private let backgroundColorProvider: () -> Color

    private static let headerHeight: CGFloat = 44
    private static let maxTaskListHeight: CGFloat = 160

    /// 单个任务行高度(`TaskRowView` 内部消费此值计算行高)。
    static let rowHeight: CGFloat = 30

    /// 是否有可见的 Goal
    private var hasVisibleGoal: Bool {
        viewModel.hasActiveWork
    }

    public init(
        conversationIdProvider: @escaping () -> UUID?,
        backgroundColorProvider: @escaping () -> Color = { Color.clear }
    ) {
        self.conversationIdProvider = { conversationIdProvider()?.uuidString }
        self.backgroundColorProvider = backgroundColorProvider
    }

    public var body: some View {
        VStack(spacing: 0) {
            if hasVisibleGoal {
                SidebarHeader(
                    activeGoal: viewModel.activeGoal,
                    progressText: viewModel.progressText,
                    isCollapsed: isCollapsed,
                    onToggleCollapsed: { isCollapsed.toggle() },
                    onRefresh: {
                        Task { await viewModel.forceRefresh() }
                    }
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
        .background {
            if hasVisibleGoal {
                backgroundColorProvider()
                    .opacity(0.82)
            }
        }
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
        .task(id: conversationIdProvider()) {
            await viewModel.refresh(conversationId: conversationIdProvider())
        }
        .onDisappear {
            viewModel.removeObserver()
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

// SidebarViewModel 已迁移至 `Sources/ViewModels/SidebarViewModel.swift`(保持 public 以兼容测试)。