import SwiftUI
import SuperLogKit
import LumiCoreKit

/// 右侧栏视图 - 展示当前会话的 Goals 和 Tasks
public struct SidebarView: View, SuperLog {
    public nonisolated static let emoji = "🎯"
    public nonisolated static let verbose = true
    public static let logger = GoalTaskPlugin.logger
    
    @StateObject private var viewModel = SidebarViewModel()
    @State private var isCollapsed = false
    
    /// 获取当前会话 ID 的闭包（返回 String）
    private let conversationIdProvider: () -> String
    
    /// 获取背景色的闭包
    private let backgroundColorProvider: () -> Color
    
    private static let headerHeight: CGFloat = 44
    private static let maxGoalListHeight: CGFloat = 200
    
    /// 是否有可见的 Goals
    private var hasVisibleGoals: Bool {
        !viewModel.goals.isEmpty
    }
    
    public init(
        conversationIdProvider: @escaping () -> UUID?,
        backgroundColorProvider: @escaping () -> Color = { Color.clear }
    ) {
        self.conversationIdProvider = { conversationIdProvider()?.uuidString ?? "" }
        self.backgroundColorProvider = backgroundColorProvider
    }
    
    public var body: some View {
        Self.logger.info("\(Self.t)body: hasVisibleGoals=\(hasVisibleGoals), goalsCount=\(viewModel.goals.count)")
        return VStack(spacing: 0) {
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
        .frame(height: hasVisibleGoals ? sidebarHeight : 0, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minWidth: hasVisibleGoals ? 280 : 0, idealWidth: hasVisibleGoals ? 360 : 0)
        .frame(minHeight: 1)  // 关键：保证视图高度至少为 1pt，SwiftUI 才会触发 onAppear
        .background {
            if hasVisibleGoals {
                backgroundColorProvider()
                    .opacity(0.82)
            }
        }
        .onAppear {
            Self.logger.info("\(Self.t)onAppear: starting initial refresh")
            Task {
                await viewModel.refresh(conversationId: conversationIdProvider())
            }
        }
        .onChange(of: conversationIdProvider()) { _, newValue in
            Self.logger.info("\(Self.t)onChange: conversationId changed to \(newValue)")
            Task {
                await viewModel.refresh(conversationId: newValue)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Label("Goals & Tasks", systemImage: "target")
                .font(.headline)
            
            Spacer()
            
            if let summary = viewModel.overallSummary {
                Text("\(summary.completedGoals)/\(summary.totalGoals)")
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
            
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 16)
                
                Text(displayItem.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                
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
                VStack(alignment: .leading, spacing: 2) {
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
        .background(Color.orange.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.system(size: 9))
                .foregroundStyle(statusColor)
                .frame(width: 12)
            
            Text(displayItem.title)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
            
            if let group = displayItem.parallelGroup {
                Text("[\(group)]")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
        }
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
        let baseHeight: CGFloat = 50
        let blockedExtra: CGFloat = (status == .blocked && blockedReason != nil) ? 20 : 0
        let taskHeight: CGFloat = CGFloat(min(taskCount, 5)) * 16 + 8
        return baseHeight + blockedExtra + taskHeight + 16
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
}

// MARK: - ViewModel

@MainActor
final public class SidebarViewModel: ObservableObject, SuperLog {
    nonisolated public static let emoji = "🎯"
    nonisolated public static let verbose = false
    public static let logger = GoalTaskPlugin.logger
    
    @Published public var goals: [GoalDisplayItem] = []
    @Published public var tasksByGoalId: [String: [GoalTaskDisplayItem]] = [:]
    @Published public var overallSummary: OverallSummary?
    @Published public var isLoading: Bool = false
    
    public var currentConversationId: String?
    private nonisolated let notificationObserverHolder = NotificationObserverHolder()
    private let initialConversationId: String?
    
    /// 每次访问时动态获取 manager，避免缓存导致初始化时序问题
    @MainActor
    private var manager: GoalStateManager? {
        let manager = GoalTaskPlugin.manager
        Self.logger.info("\(Self.t)manager accessed: \(manager != nil ? "available" : "nil")")
        return manager
    }
    
    public init(conversationId: String? = nil) {
        self.initialConversationId = conversationId
        Self.logger.info("\(Self.t)init: conversationId=\(conversationId ?? "nil")")
        
        // Start loading immediately, don't rely on SwiftUI onAppear
        if let conversationId {
            Self.logger.info("\(Self.t)init: starting initial refresh for conversationId=\(conversationId)")
            Task { @MainActor in
                await self.refresh(conversationId: conversationId)
            }
        }
    }
    
    public func removeObserver() {
        notificationObserverHolder.remove()
    }
    
    public func refresh(conversationId: UUID?) async {
        let cidString = conversationId?.uuidString
        await refresh(conversationId: cidString)
    }
    
    public func refresh(conversationId: String?) async {
        Self.logger.info("\(Self.t)refresh: called with conversationId=\(conversationId ?? "nil")")
        guard let conversationId else {
            Self.logger.info("\(Self.t)refresh: conversationId is nil, clearing goals")
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
            Self.logger.info("\(Self.t)refresh: binding notification observer")
            let observer = NotificationCenter.default.addObserver(
                forName: .goalDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let changedCid = notification.userInfo?["conversationId"] as? String
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let changedCid, changedCid == self.currentConversationId {
                        Self.logger.info("\(Self.t)notification: goalDidChange for conversationId=\(changedCid)")
                        await self.reloadFromDB()
                    }
                }
            }
            notificationObserverHolder.set(observer)
        }
        
        await reloadFromDB()
        isLoading = false
        Self.logger.info("\(Self.t)refresh: completed, loaded \(self.goals.count) goals")
    }
    
    public func forceRefresh() async {
        await reloadFromDB()
    }
    
    private func reloadFromDB() async {
        Self.logger.info("\(Self.t)reloadFromDB: started")
        guard let cid = currentConversationId else {
            Self.logger.info("\(Self.t)reloadFromDB: currentConversationId is nil, returning")
            return
        }
        Self.logger.info("\(Self.t)reloadFromDB: currentConversationId=\(cid)")
        
        guard let manager else {
            Self.logger.info("\(Self.t)reloadFromDB: manager is nil, returning")
            return
        }
        Self.logger.info("\(Self.t)reloadFromDB: manager is available, fetching goals...")
        
        let fetchedGoals = await manager.fetchGoals(conversationId: cid)
        Self.logger.info("\(Self.t)reloadFromDB: fetched \(fetchedGoals.count) goals from database")
        
        var tasksMap: [String: [GoalTaskDisplayItem]] = [:]
        for goal in fetchedGoals {
            Self.logger.info("\(Self.t)reloadFromDB: fetching tasks for goal \(goal.id)")
            let tasks = await manager.fetchTasks(goalId: goal.id)
            Self.logger.info("\(Self.t)reloadFromDB: fetched \(tasks.count) tasks for goal \(goal.id)")
            tasksMap[goal.id] = tasks.map { GoalTaskDisplayItem(from: $0) }
        }
        
        goals = fetchedGoals.map { GoalDisplayItem(from: $0) }
        tasksByGoalId = tasksMap
        Self.logger.info("\(Self.t)reloadFromDB: updated goals array to \(self.self.goals.count) items")
        
        let completed = fetchedGoals.filter { $0.status == .completed }.count
        overallSummary = OverallSummary(totalGoals: fetchedGoals.count, completedGoals: completed)
        Self.logger.info("\(Self.t)reloadFromDB: completed, total=\(fetchedGoals.count), completed=\(completed)")
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
