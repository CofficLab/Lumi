import SwiftUI
import SuperLogKit
import LumiCoreKit

/// 右侧栏视图 - 展示当前会话的单一活跃 Goal 及其 Tasks
public struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @State private var isCollapsed = false

    /// 获取当前会话 ID 的闭包（内部统一为 String?）
    private let conversationIdProvider: () -> String?

    /// 获取背景色的闭包
    private let backgroundColorProvider: () -> Color

    private static let headerHeight: CGFloat = 44
    private static let maxTaskListHeight: CGFloat = 160
    fileprivate static let rowHeight: CGFloat = 30

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
                headerView

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
        .accessibilityLabel("Goal & Tasks")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 6) {
            if let goal = viewModel.activeGoal {
                Image(systemName: goal.statusSystemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(goal.statusColor)
                    .frame(width: 16)

                Text(goal.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Label("Goal", systemImage: "target")
                    .font(.headline)
            }

            Spacer()

            if viewModel.activeGoal != nil {
                Text(viewModel.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.forceRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(isCollapsed ? "Expand" : "Collapse")
        }
        .padding(.horizontal, 12)
        .frame(height: Self.headerHeight)
    }

    // MARK: - Blocked Reason

    @ViewBuilder
    private var blockedReasonView: some View {
        if let goal = viewModel.activeGoal,
           goal.status == .blocked,
           let reason = goal.blockedReason {
            Text("⚠️ \(reason)")
                .font(.caption2)
                .foregroundStyle(.orange)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.top, 4)
        }
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(viewModel.activeTasks) { task in
                    TaskRowView(displayItem: task)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
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
        // 阻塞原因最多占 2 行（caption2 ≈ 12pt，行高约 16pt）
        if viewModel.activeGoal?.status == .blocked,
           viewModel.activeGoal?.blockedReason != nil {
            height += 36
        }
        return height
    }
}

// MARK: - Task Row

private struct TaskRowView: View {
    let displayItem: GoalTaskDisplayItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: displayItem.statusSystemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(displayItem.statusColor)
                .frame(width: 14)

            Text(displayItem.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            if let group = displayItem.parallelGroup {
                Text("[\(group)]")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: SidebarView.rowHeight)
        .background(Color.orange.opacity(0.075))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Goal Display Item

/// Goal 展示用模型（不直接暴露 SwiftData 模型到 View）
public struct GoalDisplayItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let status: Goal.GoalStatus
    public let blockedReason: String?

    public init(from goal: Goal) {
        self.id = goal.id
        self.title = goal.title
        self.status = goal.status
        self.blockedReason = goal.blockedReason
    }

    public var statusSystemImage: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .blocked: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "forward.circle"
        }
    }

    public var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .blocked: .orange
        case .failed: .red
        case .skipped: .gray
        }
    }
}

/// GoalTask 展示用模型
public struct GoalTaskDisplayItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let status: GoalTask.TaskStatus
    public let parallelGroup: String?

    public init(from task: GoalTask) {
        self.id = task.id
        self.title = task.title
        self.status = task.status
        self.parallelGroup = task.parallelGroup
    }

    public var statusSystemImage: String {
        switch status {
        case .pending: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .skipped: "forward.circle"
        }
    }

    public var statusColor: Color {
        switch status {
        case .pending: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .failed: .red
        case .skipped: .orange
        }
    }
}

// MARK: - ViewModel

@MainActor
final public class SidebarViewModel: ObservableObject {
    /// 当前活跃的 Goal（单一目标模式）
    @Published public var activeGoal: GoalDisplayItem?
    /// 当前活跃 Goal 的 Tasks
    @Published public var activeTasks: [GoalTaskDisplayItem] = []
    @Published public var isLoading: Bool = false

    public var currentConversationId: String?
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()

    public init() {}

    /// 是否有可见的 Goal（需要展示侧栏）
    public var hasActiveWork: Bool {
        guard let goal = activeGoal else { return false }
        // 终态: completed, failed, skipped - 不显示
        switch goal.status {
        case .completed, .failed, .skipped:
            // 终态下检查是否还有进行中的 task
            return activeTasks.contains { task in
                switch task.status {
                case .completed, .failed, .skipped:
                    return false
                case .pending, .inProgress:
                    return true
                }
            }
        case .pending, .inProgress, .blocked:
            return true
        }
    }

    /// 获取进度信息
    public var progressText: String {
        guard let _ = activeGoal, !activeTasks.isEmpty else { return "" }
        let completed = activeTasks.filter { $0.status == .completed || $0.status == .skipped }.count
        return "\(completed)/\(activeTasks.count)"
    }

    /// 每次访问时动态获取 manager，避免缓存导致初始化时序问题
    @MainActor
    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    public func removeObserver() {
        notificationObserverHolder.remove()
    }

    public func refresh(conversationId: String?) async {
        guard let conversationId else {
            activeGoal = nil
            activeTasks = []
            currentConversationId = nil
            isLoading = false
            return
        }

        currentConversationId = conversationId
        isLoading = true

        // 首次绑定通知
        if !notificationObserverHolder.hasObserver {
            let observer = NotificationCenter.default.addObserver(
                forName: .goalDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let changedCid = notification.userInfo?["conversationId"] as? String
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let changedCid, changedCid == self.currentConversationId {
                        await self.reloadFromDB()
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }

        await reloadFromDB()
        isLoading = false
    }

    public func forceRefresh() async {
        await reloadFromDB()
    }

    private func reloadFromDB() async {
        guard let cid = currentConversationId,
              let manager
        else { return }

        let fetchedGoals = await manager.fetchGoals(conversationId: cid)

        // 查找最新的活跃 Goal（非终态）
        let activeGoalModel = fetchedGoals.first { goal in
            switch goal.status {
            case .completed, .failed, .skipped:
                return false
            case .pending, .inProgress, .blocked:
                return true
            }
        }

        if let goal = activeGoalModel {
            activeGoal = GoalDisplayItem(from: goal)
            let tasks = await manager.fetchTasks(goalId: goal.id)
            activeTasks = tasks.map { GoalTaskDisplayItem(from: $0) }
        } else {
            activeGoal = nil
            activeTasks = []
        }
    }
}

// MARK: - Notification Observer Holder

private final class NotificationObserverHolder: @unchecked Sendable {
    private var observer: NSObjectProtocol?

    var hasObserver: Bool {
        observer != nil
    }

    deinit {
        remove()
    }

    func set(_ observer: NSObjectProtocol) {
        remove()
        self.observer = observer
    }

    func remove() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
