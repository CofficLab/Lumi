import LumiLoggingKit
import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: GoalVM

    /// 当前明暗外观：暗色主题下同样的黑色压不出层次，阴影浓度需要单独调。
    @Environment(\.colorScheme) private var colorScheme

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

    /// 顶部阴影的模糊半径(点):决定阴影顶端渐隐的柔和程度。
    ///
    /// 面板下方任务列表容器(`taskListSurface`)用的是
    /// `DesignTokens.Shadow.innerFieldBlur`(2pt)配合上下各内缩 2pt,
    /// 得到一条很紧的内阴影带。顶部阴影是**投影**而非内阴影,
    /// 扩散范围更大,半径取 4pt 才能与之读起来是同一套柔和质感。
    private static let topShadowBlur: CGFloat = 4

    /// 顶部阴影紧贴面板顶边的实心核心高度(点)。
    ///
    /// 核心保持实色,让阴影在顶边处有明确的接触感;核心之外交给模糊衰减。
    private static let topShadowCore: CGFloat = 4

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
        .overlay(alignment: .top) {
            topShadow
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(pluginLocalization.string("Goal & Tasks"))
    }

    // MARK: - Top Shadow

    /// 顶边向上投射的柔和阴影。
    ///
    /// 面板本身没有底色(与聊天区同底),SwiftUI 的 `.shadow()` 只会把文字和图标
    /// 的轮廓投影出去,画不出「整条面板浮起来」的层次,因此这里手绘一段朝上的
    /// 阴影。
    ///
    /// 阴影落在面板上方(消息列表一侧),把 Goal 面板与上方的对话内容分开,
    /// 面板因此读起来是「压在聊天区之上的一层」。
    ///
    /// 具体写法见 `GoalTopShadowView`:与面板下方任务列表容器的内阴影同源,
    /// 都是「模糊挖空」而非线性渐变,避免出现一条生硬的灰边。
    @ViewBuilder
    private var topShadow: some View {
        if hasVisibleGoal {
            GoalTopShadowView(
                opacity: topShadowOpacity,
                blurRadius: Self.topShadowBlur,
                coreHeight: Self.topShadowCore
            )
        }
    }

    /// 顶部阴影的不透明度:暗色主题下同样的黑色几乎看不出层次,故暗色更重。
    ///
    /// 阴影带已从 20pt 收窄到 12pt,峰值浓度相应下调:早先 0.18 / 0.30 是配合
    /// 20pt 宽的带调的,带窄后同样的浓度会读成一条压得很重的黑边。
    private var topShadowOpacity: Double {
        colorScheme == .dark ? 0.26 : 0.16
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
        Self.taskListHeight(forTaskCount: viewModel.activeTasks.count)
    }

    /// 任务列表容器的高度:内容高度与上限的较小值。
    ///
    /// 抽成 `internal static` 纯函数,是为了让「任务过多时容器封顶、列表内部滚动
    /// 并裁掉最后一行」这条几何约束可以被单元测试直接钉住——它决定了任务列表
    /// 实际能显示几行,却没有任何测试覆盖过。
    ///
    /// - Parameter count: 任务数量。
    /// - Returns: 容器高度(点)。0 个任务时为 0,超过 `maxTaskListHeight` 时封顶。
    static func taskListHeight(forTaskCount count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let contentHeight = CGFloat(count) * Self.rowHeight
            + CGFloat(max(0, count - 1)) * 4
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
