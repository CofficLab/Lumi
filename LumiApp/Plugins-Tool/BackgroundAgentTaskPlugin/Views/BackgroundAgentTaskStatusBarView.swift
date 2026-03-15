import Foundation
import SwiftUI

struct BackgroundAgentTaskStatusBarView: View {
    @State private var tasks: [BackgroundAgentTask] = []
    @State private var isPopoverPresented = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isPopoverPresented.toggle()
                if isPopoverPresented {
                    reload()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                    if let runningCount = runningTaskCount, runningCount > 0 {
                        Text("\(runningCount)")
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                BackgroundAgentTaskListView(tasks: tasks, onRefresh: reload)
                    .frame(width: 420, height: 300)
                    .padding(8)
            }
        }
        .onAppear {
            reload()
        }
    }

    private var runningTaskCount: Int? {
        let count = tasks.filter { BackgroundAgentTaskStatus(rawOrDefault: $0.statusRawValue) == .running }.count
        return count == 0 ? nil : count
    }

    private func reload() {
        tasks = BackgroundAgentTaskStore.shared.fetchRecent(limit: 50)
    }
}

private struct BackgroundAgentTaskListView: View {
    let tasks: [BackgroundAgentTask]
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("后台任务")
                    .font(.headline)

                Spacer()

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("刷新任务列表")
            }

            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("暂无后台任务")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(tasks, id: \.id) { task in
                        BackgroundAgentTaskRowView(task: task)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct BackgroundAgentTaskRowView: View {
    let task: BackgroundAgentTask

    var body: some View {
        let status = BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: status))
                    .foregroundColor(color(for: status))
                    .font(.system(size: 11))

                Text(task.originalPrompt)
                    .lineLimit(1)
                    .font(.system(size: 12))

                Spacer()

                if let createdAt = task.createdAtFormatted {
                    Text(createdAt)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            if let summary = task.resultSummary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else if let error = task.errorDescription, !error.isEmpty {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconName(for status: BackgroundAgentTaskStatus) -> String {
        switch status {
        case .pending:
            return "clock"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .succeeded:
            return "checkmark.circle"
        case .failed:
            return "xmark.octagon"
        }
    }

    private func color(for status: BackgroundAgentTaskStatus) -> Color {
        switch status {
        case .pending:
            return .yellow
        case .running:
            return .blue
        case .succeeded:
            return .green
        case .failed:
            return .red
        }
    }
}

private extension BackgroundAgentTask {
    var createdAtFormatted: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

