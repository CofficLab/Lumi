import Foundation
import SwiftUI

// MARK: - Background Agent Task List View

/// 后台任务列表视图（用于在 popover 中显示）
struct BackgroundTaskListView: View {
    let onRefresh: () -> Void

    @State private var currentPage: Int = 1
    @State private var pageSize: Int = 10
    @State private var total: Int = 0
    @State private var displayTasks: [BackgroundAgentTask] = []
    @State private var expandedTaskId: UUID? = nil
    @State private var showClearConfirm: Bool = false

    private var totalPages: Int {
        max(1, (total + pageSize - 1) / pageSize)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            tableContent
            paginationBar
        }
        .frame(minHeight: 500)
        .alert(L10n.confirmClearTitle, isPresented: $showClearConfirm) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.clearCompleted, role: .destructive) {
                BackgroundAgentTaskStore.shared.deleteCompleted()
                loadPage(min(currentPage, totalPages))
                onRefresh()
            }
        } message: {
            Text(L10n.confirmClearMessage)
        }
        .onAppear {
            loadPage(1)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(L10n.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()

            Text(L10n.totalCount(total))
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Button {
                showClearConfirm = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                    Text(L10n.clearCompleted)
                        .font(.system(size: 10))
                }
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
            .buttonStyle(.plain)
            .help(L10n.clearCompletedHelp)
            .disabled(total == 0)

            Button {
                loadPage(currentPage)
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .help(L10n.refresh)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Table Content

    private var tableContent: some View {
        VStack(spacing: 0) {
            tableHeaderRow

            Divider()

            if displayTasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayTasks, id: \.id) { task in
                            taskRow(task)
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            tableColumn(L10n.colStatus, width: 60)
            tableColumn(L10n.colPrompt, width: nil)
            tableColumn(L10n.colCreatedAt, width: 100)
            tableColumn(L10n.colDuration, width: 50, alignment: .trailing)
            tableColumn(L10n.colActions, width: 60, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.06))
    }

    private func tableColumn(_ title: String, width: CGFloat?, alignment: HorizontalAlignment = .leading) -> some View {
        Group {
            if let width {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .frame(width: width, alignment: alignment == .trailing ? .trailing : (alignment == .center ? .center : .leading))
            } else {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            Text(L10n.emptyTitle)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Task Row

    private func taskRow(_ task: BackgroundAgentTask) -> some View {
        let status = BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue)
        let isExpanded = expandedTaskId == task.id

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 状态列 - 保留颜色以区分状态
                HStack(spacing: 4) {
                    Image(systemName: iconName(for: status))
                        .font(.system(size: 10))
                        .foregroundColor(color(for: status))
                    Text(statusLabel(for: status))
                        .font(.system(size: 11))
                        .foregroundColor(color(for: status))
                }
                .frame(width: 60, alignment: .leading)

                // 指令列
                Text(task.originalPrompt)
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 创建时间列
                Text(shortTime(task.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .frame(width: 100, alignment: .leading)

                // 耗时列
                Text(durationText(task: task))
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .frame(width: 50, alignment: .trailing)

                // 操作列 - 只保留删除按钮
                Button {
                    deleteTask(task)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .frame(width: 18, height: 18)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.deleteHelp)
                .frame(width: 60, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expandedTaskId = isExpanded ? nil : task.id
                }
            }

            if isExpanded {
                taskDetail(task)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private func taskDetail(_ task: BackgroundAgentTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.promptFull)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                Text(task.originalPrompt)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let summary = task.resultSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.resultLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let error = task.errorDescription, !error.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.errorLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.error)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.05))
        )
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        HStack(spacing: 0) {
            Button {
                if currentPage > 1 { loadPage(currentPage - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(currentPage > 1 ? DesignTokens.Color.semantic.textSecondary : DesignTokens.Color.semantic.textDisabled)
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 1)

            Spacer()

            Text(L10n.pageIndicator(currentPage, totalPages))
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Spacer()

            Button {
                if currentPage < totalPages { loadPage(currentPage + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(currentPage < totalPages ? DesignTokens.Color.semantic.textSecondary : DesignTokens.Color.semantic.textDisabled)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= totalPages)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func deleteTask(_ task: BackgroundAgentTask) {
        BackgroundAgentTaskStore.shared.delete(task.id)
        loadPage(min(currentPage, max(1, totalPages)))
        onRefresh()
    }

    private func loadPage(_ page: Int) {
        let result = BackgroundAgentTaskStore.shared.fetchPage(page: page, pageSize: pageSize)
        displayTasks = result.tasks
        total = result.total
        currentPage = page
        expandedTaskId = nil
    }

    // MARK: - Helpers

    private func iconName(for status: BackgroundAgentTaskStatus) -> String {
        switch status {
        case .pending: return "clock"
        case .running: return "arrow.triangle.2.circlepath"
        case .succeeded: return "checkmark.circle"
        case .failed: return "xmark.octagon"
        }
    }

    private func color(for status: BackgroundAgentTaskStatus) -> Color {
        switch status {
        case .pending: return .yellow
        case .running: return .blue
        case .succeeded: return .green
        case .failed: return .red
        }
    }

    private func statusLabel(for status: BackgroundAgentTaskStatus) -> String {
        switch status {
        case .pending: return L10n.statusPending
        case .running: return L10n.statusRunning
        case .succeeded: return L10n.statusSucceeded
        case .failed: return L10n.statusFailed
        }
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func durationText(task: BackgroundAgentTask) -> String {
        let start = task.startedAt ?? task.createdAt
        let end = task.finishedAt ?? Date()
        let interval = end.timeIntervalSince(start)

        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            return String(format: "%.1fh", interval / 3600)
        }
    }
}

// MARK: - Localization

private enum L10n {
    static let table = "BackgroundAgentTask"

    static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: table)
    }

    static func localized(_ key: String, _ args: CVarArg...) -> String {
        String(format: localized(key), arguments: args)
    }

    // Header
    static var title: String { localized("Background Tasks") }
    static func totalCount(_ count: Int) -> String { L10n.localized("Total: %lld", count) }
    static var clearCompleted: String { localized("Clear Completed") }
    static var clearCompletedHelp: String { localized("Clear all completed and failed tasks") }
    static var refresh: String { localized("Refresh") }

    // Alert
    static var confirmClearTitle: String { localized("Confirm Clear") }
    static var cancel: String { localized("Cancel") }
    static var confirmClearMessage: String { localized("Are you sure you want to clear all completed and failed tasks? This action cannot be undone.") }

    // Table
    static var colStatus: String { localized("Status") }
    static var colPrompt: String { localized("Instruction") }
    static var colCreatedAt: String { localized("Created At") }
    static var colDuration: String { localized("Duration") }
    static var colActions: String { localized("Actions") }
    static var emptyTitle: String { localized("No background tasks") }

    // Detail
    static var promptFull: String { localized("Full Instruction") }
    static var resultLabel: String { localized("Result") }
    static var errorLabel: String { localized("Error Message") }
    static var deleteHelp: String { localized("Delete this task") }

    // Pagination
    static func pageIndicator(_ current: Int, _ total: Int) -> String {
        L10n.localized("Page %lld / %lld", current, total)
    }

    // Status
    static var statusPending: String { localized("Pending") }
    static var statusRunning: String { localized("Running") }
    static var statusSucceeded: String { localized("Completed") }
    static var statusFailed: String { localized("Failed") }
}
