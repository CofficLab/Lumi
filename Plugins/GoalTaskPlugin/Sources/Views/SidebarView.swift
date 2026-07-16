import SwiftUI
import SuperLogKit
import LumiCoreKit

/// 右侧栏视图 - 展示当前会话的 Goals 和 Tasks
public struct SidebarView: View {
    @StateObject private var viewModel = SidebarViewModel()
    @State private var isCollapsed = false

    /// 获取当前会话 ID 的闭包（内部统一为 String?）
    private let conversationIdProvider: () -> String?

    /// 获取背景色的闭包
    private let backgroundColorProvider: () -> Color

    private static let headerHeight: CGFloat = 44
    private static let maxGoalListHeight: CGFloat = 200

    /// 是否有可见的 Goals
    ///
    /// 与 AutoTask 的 `isAllDone` 对齐：只要有未到终态的 Goal（或其下还有 pending/inProgress 的 Task），
    /// 就继续展示；全部完成/失败/跳过后立即隐藏——不依赖 TurnFinishedHook 的数据清理时序。
    private var hasVisibleGoals: Bool {
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
            if hasVisibleGoals {
                headerView

                if isCollapsed {
                    EmptyView()
                } else if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.vertical, 8)
                } else {
                    goalListView
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: hasVisibleGoals ? sidebarHeight : 0)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minWidth: hasVisibleGoals ? 240 : 0, idealWidth: hasVisibleGoals ? 320 : 0)
        .background {
            if hasVisibleGoals {
                backgroundColorProvider()
                    .opacity(0.82)
            }
        }
        .overlay {
            if hasVisibleGoals {
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
        .accessibilityLabel("Goals & Tasks")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Label("Goals & Tasks", systemImage: "target")
                .font(.headline)

            Spacer()

            if let summary = viewModel.overallSummary {
                Text("\(summary.completedGoals)/\(summary.totalGoals) (\(summary.completionPercent)%)")
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

    // MARK: - Goal List

    private var goalListView: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(viewModel.goals) { goal in
                    GoalCardView(displayItem: goal, tasks: viewModel.tasksByGoalId[goal.id] ?? [])
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(height: goalListHeight)
    }

    private var goalListHeight: CGFloat {
        let totalHeight = viewModel.goals.reduce(CGFloat(0)) { acc, goal in
            acc + goal.estimatedHeight(taskCount: viewModel.tasksByGoalId[goal.id]?.count ?? 0)
        }
        return min(totalHeight, Self.maxGoalListHeight)
    }

    private var sidebarHeight: CGFloat {
        guard hasVisibleGoals else { return 0 }
        if isCollapsed {
            return Self.headerHeight
        }
        if viewModel.isLoading {
            return Self.headerHeight + 32
        }
        return Self.headerHeight + goalListHeight
    }
}

// MARK: - Goal Card

private struct GoalCardView: View {
    let displayItem: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Goal Header
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 14)

                Text(displayItem.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Text("\(completedCount)/\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Blocked reason
            if displayItem.status == .blocked, let reason = displayItem.blockedReason {
                Text("⚠️ \(reason)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            // Tasks
            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tasks.prefix(5)) { task in
                        TaskRowView(displayItem: task)
                    }
                    if tasks.count > 5 {
                        Text("... and \(tasks.count - 5) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(Color.orange.opacity(0.075))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.orange.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var statusIcon: String {
        switch displayItem.status {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.circle"
        }
    }

    private var statusColor: Color {
        switch displayItem.status {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .blocked: return .orange
        case .failed: return .red
        case .skipped: return .gray
        }
    }

    private var completedCount: Int {
        tasks.filter { $0.status == .completed || $0.status == .skipped }.count
    }
}

// MARK: - Task Row

private struct TaskRowView: View {
    let displayItem: GoalTaskDisplayItem

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 12)

            Text(displayItem.title)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)

            if let group = displayItem.parallelGroup {
                Text("[\(group)]")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(Color.orange.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var statusIcon: String {
        switch displayItem.status {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.circle"
        }
    }

    private var statusColor: Color {
        switch displayItem.status {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

// MARK: - Display Items

extension Goal.GoalStatus {
    /// 是否为终态（不再会有后续推进）。
    /// 注意：blocked 不算终态——它需要用户介入，侧栏应保持可见以提示用户。
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped:
            return true
        case .pending, .inProgress, .blocked:
            return false
        }
    }
}

extension GoalTask.TaskStatus {
    /// 是否为终态。
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .skipped:
            return true
        case .pending, .inProgress:
            return false
        }
    }
}

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
    
    /// 估算高度
    public func estimatedHeight(taskCount: Int) -> CGFloat {
        let baseHeight: CGFloat = 48
        let blockedExtra: CGFloat = (status == .blocked && blockedReason != nil) ? 20 : 0
        let visibleTasks = min(taskCount, 5)
        let taskHeight: CGFloat = CGFloat(visibleTasks) * 22 + CGFloat(max(0, visibleTasks - 1)) * 4
        let overflowExtra: CGFloat = taskCount > 5 ? 16 : 0
        return baseHeight + blockedExtra + taskHeight + overflowExtra + 16
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
}

// MARK: - Overall Summary

public struct OverallSummary {
    public let totalGoals: Int
    public let completedGoals: Int

    /// 完成百分比 (0-100)
    public var completionPercent: Int {
        guard totalGoals > 0 else { return 0 }
        return Int(Double(completedGoals) / Double(totalGoals) * 100)
    }
}

// MARK: - ViewModel

@MainActor
final public class SidebarViewModel: ObservableObject {
    @Published public var goals: [GoalDisplayItem] = []
    @Published public var tasksByGoalId: [String: [GoalTaskDisplayItem]] = [:]
    @Published public var overallSummary: OverallSummary?
    @Published public var isLoading: Bool = false

    public var currentConversationId: String?
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()

    public init() {}

    /// 是否还有进行中的工作（需要展示侧栏）。
    ///
    /// 与 AutoTask 的 `isAllDone` 取反语义一致：只要存在未到终态的 Goal，
    /// 或任一 Task 仍为 pending/inProgress，就返回 true。
    /// 全部到达终态后返回 false，侧栏立即隐藏——不依赖数据被删除。
    public var hasActiveWork: Bool {
        guard !goals.isEmpty else { return false }
        return goals.contains { goal in
            if goal.status.isTerminal {
                // 终态 Goal：确认其下没有残留的进行中任务
                let tasks = tasksByGoalId[goal.id] ?? []
                return tasks.contains { !$0.status.isTerminal }
            }
            return true
        }
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
            goals = []
            tasksByGoalId = [:]
            overallSummary = nil
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

        var tasksMap: [String: [GoalTaskDisplayItem]] = [:]
        for goal in fetchedGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            tasksMap[goal.id] = tasks.map { GoalTaskDisplayItem(from: $0) }
        }

        goals = fetchedGoals.map { GoalDisplayItem(from: $0) }
        tasksByGoalId = tasksMap

        let completed = fetchedGoals.filter { $0.status == .completed }.count
        overallSummary = OverallSummary(totalGoals: fetchedGoals.count, completedGoals: completed)
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
