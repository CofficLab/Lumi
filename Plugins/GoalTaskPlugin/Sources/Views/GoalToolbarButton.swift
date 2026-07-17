import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

// MARK: - Goal Toolbar Button

/// 显示在 chat 工具栏的 Goal 按钮，点击展示当前活跃 goal 详情
struct GoalToolbarButton: View {
    @Environment(\.lumiCore) private var lumiCore
    @StateObject private var viewModel = GoalToolbarViewModel()
    @State private var isPopoverPresented = false

    private var goalCount: Int {
        viewModel.hasActiveGoal ? 1 : 0
    }

    var body: some View {
        Button {
            Task {
                await viewModel.refresh(lumiCore: lumiCore)
            }
            isPopoverPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .medium))

                if goalCount > 0 {
                    Text("\(goalCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -4)
                }
            }
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
    @Published public var activeGoal: GoalDisplayItem?
    @Published public var activeTasks: [GoalTaskDisplayItem] = []
    @Published public var isLoading: Bool = false

    private var currentConversationId: String?

    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    public var hasActiveGoal: Bool {
        activeGoal != nil
    }

    func refresh(lumiCore: LumiCoreAccessing?) async {
        guard let manager else { return }

        guard let chatService = lumiCore?.chatService else { return }

        guard let conversationID = chatService.selectedConversationID ?? chatService.conversations.first?.id else {
            activeGoal = nil
            activeTasks = []
            return
        }

        await loadGoals(conversationId: conversationID.uuidString, manager: manager)
    }

    private func loadGoals(conversationId: String, manager: GoalStateManager) async {
        guard conversationId != currentConversationId else { return }

        currentConversationId = conversationId
        isLoading = true

        let fetchedGoals = await manager.fetchGoals(conversationId: conversationId)

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

        isLoading = false
    }
}

// MARK: - Goal Popover Content

private struct GoalPopoverContent: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: GoalToolbarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Goal", systemImage: "target")
                    .font(.headline)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let goal = viewModel.activeGoal {
                ScrollView {
                    GoalRowView(goal: goal, tasks: viewModel.activeTasks)
                        .padding(12)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No active goal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .background(theme.background)
    }
}

// MARK: - Goal Row View

private struct GoalRowView: View {
    let goal: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.status == .completed || $0.status == .skipped }.count
        return Double(completedCount) / Double(tasks.count)
    }

    private var statusColor: Color {
        switch goal.status {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .blocked: return .orange
        case .failed: return .red
        case .skipped: return .secondary
        }
    }

    private var statusIcon: String {
        switch goal.status {
        case .pending: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Goal Header
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor)

                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(goal.status.rawValue.replacingOccurrences(of: "_", with: " "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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

            // Task count
            Text("\(tasks.filter { $0.status == .completed || $0.status == .skipped }.count)/\(tasks.count) tasks")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let blockedReason = goal.blockedReason, goal.status == .blocked {
                Text("⚠️ \(blockedReason)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Task List
            Text("Tasks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(tasks) { task in
                HStack(spacing: 6) {
                    Image(systemName: taskStatusIcon(task.status))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(taskStatusColor(task.status))
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
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func taskStatusIcon(_ status: GoalTask.TaskStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .inProgress: return "play.fill"
        case .completed: return "checkmark"
        case .failed: return "xmark"
        case .skipped: return "forward"
        }
    }

    private func taskStatusColor(_ status: GoalTask.TaskStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    GoalToolbarButton()
        .padding()
}
