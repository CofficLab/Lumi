import SwiftUI
import SuperLogKit
import LumiKernel

/// 右侧栏视图 - 展示当前会话的单一活跃 Goal 及其 Tasks
///
/// 数据完全来自外部注入的 `SidebarViewModel`,本视图不感知数据来源;
/// 视图仅负责根据 ViewModel 的状态进行渲染,并把"切换会话"事件
/// 透传给 ViewModel(`refresh(conversationId:)`)。
public struct SidebarView: View {
    /// 外部注入的视图模型,由调用方(如 Plugin)持有并管理生命周期。
    @ObservedObject var viewModel: SidebarViewModel

    /// 弱引用宿主 kernel,仅用于读取 `selectedConversationID`,
    /// 不作为数据源持有。
    private weak var kernel: LumiKernel?

    @State private var isCollapsed = false

    private static let headerHeight: CGFloat = 44
    private static let maxTaskListHeight: CGFloat = 160

    /// 单个任务行高度(`TaskRowView` 内部消费此值计算行高)。
    static let rowHeight: CGFloat = 30

    /// 是否有可见的 Goal
    private var hasVisibleGoal: Bool {
        viewModel.hasActiveWork
    }

    public init(viewModel: SidebarViewModel, kernel: LumiKernel) {
        self.viewModel = viewModel
        // kernel 字段为 weak,Swift 在赋值时自动转为弱引用,
        // 避免 View(值类型)意外延长宿主 kernel 的生命周期。
        self.kernel = kernel
    }

    /// 获取当前会话 ID,内部统一为 String?
    private var currentConversationId: String? {
        kernel?.conversations?.selectedConversationID?.uuidString
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
        .task(id: currentConversationId) {
            await viewModel.refresh(conversationId: currentConversationId)
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
