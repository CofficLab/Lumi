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
        .alert("Confirm Clear", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Completed", role: .destructive) {
                BackgroundAgentTaskStore.shared.deleteCompleted()
                loadPage(min(currentPage, totalPages))
                onRefresh()
            }
        } message: {
            Text("Are you sure you want to clear all completed and failed tasks? This action cannot be undone.")
        }
        .onAppear {
            loadPage(1)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(L10n.title)
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer()

            AppButton(
                "Clear Completed",
                systemImage: "trash",
                style: .ghost,
                size: .small,
                action: { showClearConfirm = true }
            )
            .disabled(total == 0)

            AppIconButton(
                systemImage: "arrow.clockwise",
                tint: AppUI.Color.semantic.textSecondary,
                action: {
                    loadPage(currentPage)
                    onRefresh()
                }
            )
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.bottom, AppUI.Spacing.sm)
    }

    // MARK: - Table Content

    private var tableContent: some View {
        VStack(spacing: 0) {
            tableHeaderRow

            GlassDivider()

            if displayTasks.isEmpty {
                AppEmptyState(
                    icon: "tray",
                    title: "No background tasks"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayTasks, id: \.id) { task in
                            taskRow(task)
                            GlassDivider().opacity(0.3)
                        }
                    }
                }
            }
        }
    }

    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            tableColumn(L10n.colStatus, width: 80)
            tableColumn(L10n.colPrompt, width: nil)
            tableColumn(L10n.colCreatedAt, width: 100)
            tableColumn(L10n.colDuration, width: 60, alignment: .trailing)
            tableColumn(L10n.colActions, width: 50, alignment: .center)
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
        .background(AppUI.Color.semantic.textTertiary.opacity(0.06))
    }

    private func tableColumn(_ title: String, width: CGFloat?, alignment: HorizontalAlignment = .leading) -> some View {
        Group {
            if let width {
                Text(title)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .frame(width: width, alignment: alignment == .trailing ? .trailing : (alignment == .center ? .center : .leading))
            } else {
                Text(title)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Task Row

    private func taskRow(_ task: BackgroundAgentTask) -> some View {
        let status = BackgroundAgentTaskStatus(rawOrDefault: task.statusRawValue)
        let isExpanded = expandedTaskId == task.id

        return GlassRow {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // 状态列 - 使用 GlassBadge
                    statusBadge(for: status)
                        .frame(width: 80, alignment: .leading)

                    // 指令列
                    Text(task.originalPrompt)
                        .font(AppUI.Typography.body)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 创建时间列
                    Text(shortTime(task.createdAt))
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .frame(width: 100, alignment: .leading)

                    // 耗时列
                    Text(durationText(task: task))
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .frame(width: 60, alignment: .trailing)

                    // 操作列 - 使用 AppIconButton
                    AppIconButton(
                        systemImage: "xmark",
                        tint: AppUI.Color.semantic.textTertiary,
                        action: { deleteTask(task) }
                    )
                    .frame(width: 50, alignment: .center)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: AppUI.Duration.micro)) {
                        expandedTaskId = isExpanded ? nil : task.id
                    }
                }

                if isExpanded {
                    taskDetail(task)
                        .padding(.top, AppUI.Spacing.sm)
                }
            }
        }
    }

    private func taskDetail(_ task: BackgroundAgentTask) -> some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
            // 指令全文
            GlassKeyValueRow(label: L10n.promptFull, value: task.originalPrompt)

            // 执行结果或错误信息
            if let summary = task.resultSummary, !summary.isEmpty {
                GlassKeyValueRow(label: L10n.resultLabel, value: summary)
            } else if let error = task.errorDescription, !error.isEmpty {
                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    Text(L10n.errorLabel)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                    Text(error)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.error)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(AppUI.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .fill(AppUI.Color.semantic.textTertiary.opacity(0.05))
        )
    }

    // MARK: - Pagination Bar

    private var paginationBar: some View {
        HStack(spacing: 0) {
            AppIconButton(
                systemImage: "chevron.left",
                tint: currentPage > 1 ? AppUI.Color.semantic.textSecondary : AppUI.Color.semantic.textDisabled,
                action: { if currentPage > 1 { loadPage(currentPage - 1) } }
            )
            .disabled(currentPage <= 1)

            Spacer()

            // 合并显示：共 X 条 · 第 x/y 页
            Text(L10n.paginationInfo(total: total, page: currentPage, totalPages: totalPages))
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Spacer()

            AppIconButton(
                systemImage: "chevron.right",
                tint: currentPage < totalPages ? AppUI.Color.semantic.textSecondary : AppUI.Color.semantic.textDisabled,
                action: { if currentPage < totalPages { loadPage(currentPage + 1) } }
            )
            .disabled(currentPage >= totalPages)
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
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

    private func badgeStyle(for status: BackgroundAgentTaskStatus) -> GlassBadge.Style {
        switch status {
        case .pending: return .warning
        case .running: return .info
        case .succeeded: return .success
        case .failed: return .error
        }
    }

    private func statusBadge(for status: BackgroundAgentTaskStatus) -> some View {
        let style = badgeStyle(for: status)
        let label: LocalizedStringKey = switch status {
        case .pending: "Pending"
        case .running: "Running"
        case .succeeded: "Completed"
        case .failed: "Failed"
        }
        return GlassBadge(text: label, style: style)
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

    // Header - String for Text view
    static var title: String { localized("Background Tasks") }

    // Table columns - String for Text view
    static var colStatus: String { localized("Status") }
    static var colPrompt: String { localized("Instruction") }
    static var colCreatedAt: String { localized("Created At") }
    static var colDuration: String { localized("Duration") }
    static var colActions: String { localized("Actions") }

    // Detail labels - String for GlassKeyValueRow
    static var promptFull: String { localized("Full Instruction") }
    static var resultLabel: String { localized("Result") }
    static var errorLabel: String { localized("Error Message") }

    // Pagination - 合并显示总数和页码
    static func paginationInfo(total: Int, page: Int, totalPages: Int) -> String {
        // 格式：共 X 条 · 第 x/y 页
        let totalStr = localized("Total: %lld").replacingOccurrences(of: "%lld", with: "\(total)")
        let pageStr = localized("Page %lld / %lld")
            .replacingOccurrences(of: "%lld", with: "\(page)")
            .replacingOccurrences(of: "%lld", with: "\(totalPages)")
        return "\(totalStr) · \(pageStr)"
    }
}