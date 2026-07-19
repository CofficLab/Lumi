import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

// MARK: - Goal Toolbar Button

/// 显示在 chat 工具栏的 Goal 按钮（Verbosity 按钮右侧），点击展示当前对话的所有 Goal 列表。
struct GoalToolbarButton: View {
    @ObservedObject private var chatService: ChatService
    @StateObject private var viewModel: GoalToolbarViewModel
    @State private var isPopoverPresented = false

    private var goalCount: Int {
        viewModel.goals.count
    }

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("GoalToolbarButton requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
        _viewModel = StateObject(wrappedValue: GoalToolbarViewModel(chatService: chatService))
    }

    var body: some View {
        Button {
            Task {
                await viewModel.refresh()
            }
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .medium))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            GoalPopoverContent(viewModel: viewModel)
                .frame(width: 320, height: 400)
        }
    }
}

// MARK: - Goal Toolbar ViewModel

@MainActor
final class GoalToolbarViewModel: ObservableObject {
    /// 当前对话的所有 Goal（每个携带自己的任务），按创建时间升序。
    @Published public var goals: [GoalListItem] = []
    @Published public var isLoading: Bool = false

    private let chatService: ChatService

    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    /// 是否有活跃（非终态）Goal，供外部判断。
    public var hasActiveGoal: Bool {
        goals.contains { (item: GoalListItem) in item.goal.isTerminal == false }
    }

    init(chatService: ChatService) {
        self.chatService = chatService
    }

    func refresh() async {
        guard let manager else { return }

        guard let conversationID = chatService.selectedConversationID ?? chatService.conversations.first?.id else {
            goals = []
            return
        }

        await loadGoals(conversationId: conversationID.uuidString, manager: manager)
    }

    private func loadGoals(conversationId: String, manager: GoalStateManager) async {
        // 每次点击都重新拉取最新列表（用户可能在外部新增了 goal）。
        isLoading = true

        let fetchedGoals = await manager.fetchGoals(conversationId: conversationId)

        // 逐个加载每个 goal 的任务（SwiftData 关系跨 ModelContext 不可靠，必须显式查询）。
        var items: [GoalListItem] = []
        for goal in fetchedGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            items.append(GoalListItem(
                goal: GoalDisplayItem(from: goal),
                tasks: tasks.map { GoalTaskDisplayItem(from: $0) }
            ))
        }
        goals = items
        isLoading = false
    }
}

/// 一个 Goal 及其任务的展示组合（用于工具栏弹窗的列表项）。
struct GoalListItem: Identifiable, Equatable {
    let goal: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]

    var id: String { goal.id }
}

// MARK: - Goal Popover Content

private struct GoalPopoverContent: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: GoalToolbarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Goals", systemImage: "target")
                    .font(.headline)

                Spacer()

                if !viewModel.goals.isEmpty {
                    Text("\(viewModel.goals.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if viewModel.isLoading && viewModel.goals.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.goals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No goals yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.goals) { item in
                            GoalRowView(item: item)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(theme.background)
    }
}

// MARK: - Goal Row View

private struct GoalRowView: View {
    let item: GoalListItem
    @State private var isExpanded = false

    private var goal: GoalDisplayItem { item.goal }
    private var tasks: [GoalTaskDisplayItem] { item.tasks }

    private var completedCount: Int {
        tasks.filter { $0.status == .completed || $0.status == .skipped }.count
    }

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private var statusColor: Color {
        goal.statusColor
    }

    private var statusIcon: String {
        goal.statusSystemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Goal Header（点击展开/折叠任务）
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 14)

                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    Text("\(completedCount)/\(tasks.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            if let blockedReason = goal.blockedReason, goal.status == .blocked {
                Text("⚠️ \(blockedReason)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }

            // 展开后的任务列表
            if isExpanded && !tasks.isEmpty {
                Divider()

                ForEach(tasks) { task in
                    HStack(spacing: 6) {
                        Image(systemName: task.statusSystemImage)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(task.statusColor)
                            .frame(width: 10)

                        Text(task.title)
                            .font(.caption)
                            .lineLimit(2)

                        if let group = task.parallelGroup {
                            Text("[\(group)]")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

