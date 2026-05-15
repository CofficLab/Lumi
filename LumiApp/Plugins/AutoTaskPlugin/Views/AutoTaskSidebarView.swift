import SwiftUI
import MagicKit

/// AutoTask 右侧栏视图
///
/// 展示当前会话的任务列表，由 AutoTaskPlugin 通过 `addSidebarSections()` 注册。
struct AutoTaskSidebarView: View {
    @EnvironmentObject var conversationVM: ConversationVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = AutoTaskSidebarViewModel()
    @State private var taskListContentHeight: CGFloat = Self.maxTaskListHeight

    private static let maxSidebarHeight: CGFloat = 200
    private static let maxTaskListHeight: CGFloat = 160

    /// 是否有正在进行的任务（需要显示 UI）
    private var hasVisibleTasks: Bool {
        guard let summary = viewModel.summary, !summary.isEmpty else { return false }
        return !summary.isAllDone
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasVisibleTasks {
                headerView

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.vertical, 8)
                } else {
                    taskListView
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: hasVisibleTasks ? Self.maxSidebarHeight : nil)
        .frame(minWidth: hasVisibleTasks ? 240 : 0, idealWidth: hasVisibleTasks ? 320 : 0)
        .background(hasVisibleTasks ? themeVM.activeAppTheme.workspaceBackgroundColor().opacity(0.6) : nil)
        .task(id: conversationVM.selectedConversationId) {
            await viewModel.refresh(conversationId: conversationVM.selectedConversationId)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Task List", table: "AutoTask"))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Label(String(localized: "Tasks", table: "AutoTask"), systemImage: "checklist")
                .font(.headline)

            Spacer()

            if let summary = viewModel.summary, !summary.isEmpty {
                Text("\(summary.completed + summary.skipped)/\(summary.total) (\(summary.completionPercent)%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                Task { await viewModel.forceRefresh() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(String(localized: "Refresh", table: "AutoTask"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.tasks) { task in
                    TaskRowView(task: task)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TaskListContentHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
        }
        .frame(height: min(taskListContentHeight, Self.maxTaskListHeight))
        .onPreferenceChange(TaskListContentHeightKey.self) { height in
            taskListContentHeight = max(0, height)
        }
    }
}

private struct TaskListContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Task Row

private struct TaskRowView: View {
    let task: TaskDisplayItem

    var body: some View {
        HStack(spacing: 6) {
            Text(task.statusIcon)
                .font(.caption2)

            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview

#Preview("AutoTask Sidebar - With Tasks") {
    AutoTaskSidebarView()
        .inRootView()
        .frame(width: 350, height: 600)
}

#Preview("AutoTask Sidebar - Empty") {
    AutoTaskSidebarView()
        .inRootView()
        .frame(width: 350, height: 600)
}
