import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

// MARK: - Goal Toolbar Button

/// 显示在 chat 工具栏的 Goal 按钮，点击展示 goals 详情
struct GoalToolbarButton: View {
    @LumiTheme private var theme
    @StateObject private var viewModel = GoalToolbarViewModel()
    @State private var isPopoverPresented = false

    private var goalCount: Int {
        viewModel.goals.count
    }

    var body: some View {
        Button {
            Task {
                await viewModel.refresh()
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
    @Published public var goals: [GoalDisplayItem] = []
    @Published public var tasksByGoalId: [String: [GoalTaskDisplayItem]] = [:]
    @Published public var isLoading: Bool = false

    private var currentConversationId: String?

    private var manager: GoalStateManager? {
        GoalTaskPlugin.currentManager()
    }

    func refresh() async {
        guard let manager else { return }

        // 延迟获取 coordinator，避免初始化时序问题
        let coordinator: ChatSectionCoordinator? = await MainActor.run {
            // 尝试从 context 获取，或者从全局获取
            LumiCore.current?.pluginContext?.resolve(ChatSectionCoordinator.self)
        }

        guard let coordinator else {
            // 如果无法获取 coordinator，使用 chatService 获取
            if let chatService = LumiCore.current?.pluginContext?.resolve(LumiChatServicing.self) as? ChatService,
               let conversationID = chatService.selectedConversationID ?? chatService.conversations.first?.id {
                await loadGoals(conversationId: conversationID.uuidString, manager: manager)
            }
            return
        }

        if let conversationID = coordinator.selectedConversationID {
            await loadGoals(conversationId: conversationID.uuidString, manager: manager)
        }
    }

    private func loadGoals(conversationId: String, manager: GoalStateManager) async {
        guard conversationId != currentConversationId else { return }

        currentConversationId = conversationId
        isLoading = true

        let fetchedGoals = await manager.fetchGoals(conversationId: conversationId)

        var tasksMap: [String: [GoalTaskDisplayItem]] = [:]
        for goal in fetchedGoals {
            let tasks = await manager.fetchTasks(goalId: goal.id)
            tasksMap[goal.id] = tasks.map { GoalTaskDisplayItem(from: $0) }
        }

        goals = fetchedGoals.map { GoalDisplayItem(from: $0) }
        tasksByGoalId = tasksMap
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
                Label("Goals", systemImage: "target")
                    .font(.headline)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("\(viewModel.goals.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if viewModel.goals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No active goals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Goals will appear here when created")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.goals) { goal in
                            GoalRowView(
                                goal: goal,
                                tasks: viewModel.tasksByGoalId[goal.id] ?? []
                            )
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
    let goal: GoalDisplayItem
    let tasks: [GoalTaskDisplayItem]

    private var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completedCount = tasks.filter { $0.status == .completed || $0.status == .skipped }.count
        return Double(completedCount) / Double(tasks.count)
    }

    private var statusColor: Color {
        switch goal.status {
        case .pending:
            return .secondary
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .blocked:
            return .orange
        case .failed:
            return .red
        case .skipped:
            return .secondary
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor)

                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

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
            HStack {
                Text("\(tasks.filter { $0.status == .completed || $0.status == .skipped }.count)/\(tasks.count) tasks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if let blockedReason = goal.blockedReason, goal.status == .blocked {
                    Text("⚠️ \(blockedReason)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    GoalToolbarButton()
        .padding()
}
