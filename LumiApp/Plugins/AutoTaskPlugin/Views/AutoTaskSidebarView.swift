import SwiftUI
import MagicKit

/// AutoTask 右侧栏视图
///
/// 展示当前会话的任务列表，由 AutoTaskPlugin 通过 `addSidebarSections()` 注册。
struct AutoTaskSidebarView: View {
    @EnvironmentObject var conversationVM: ConversationVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = AutoTaskSidebarViewModel()
    @State private var lastConversationId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            headerView

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else if viewModel.tasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .frame(maxHeight: 200)
        .frame(minWidth: 240, idealWidth: 320)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor().opacity(0.6))
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(String(localized: "No tasks yet", table: "AutoTask"))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(String(localized: "Tasks will appear when the Agent breaks down a complex goal.", table: "AutoTask"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
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
        }
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
