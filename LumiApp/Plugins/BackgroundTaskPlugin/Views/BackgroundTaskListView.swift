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
        .alert(String(localized: "Confirm Clear", table: "BackgroundAgentTask"), isPresented: $showClearConfirm) {
            Button(String(localized: "Cancel", table: "BackgroundAgentTask"), role: .cancel) {}
            Button(String(localized: "Clear Completed", table: "BackgroundAgentTask"), role: .destructive) {
                BackgroundAgentTaskStore.shared.deleteCompleted()
                loadPage(min(currentPage, totalPages))
                onRefresh()
            }
        } message: {
            Text(String(localized: "Are you sure you want to clear all completed and failed tasks? This action cannot be undone.", table: "BackgroundAgentTask"))
        }
        .onAppear {
            loadPage(1)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(String(localized: "Background Tasks", table: "BackgroundAgentTask"))
                .font(AppUI.Typography.bodyEmphasized)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer()

            Button {
                showClearConfirm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text(String(localized: "Clear Completed", table: "BackgroundAgentTask"))
                }
                .font(AppUI.Typography.caption1)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
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
                VStack(spacing: AppUI.Spacing.md) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(AppUI.Color.semantic.textSecondary.opacity(0.6))
                    Text(String(localized: "No background tasks", table: "BackgroundAgentTask"))
                        .font(AppUI.Typography.bodyEmphasized)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(AppUI.Spacing.xl)
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
            tableColumn(String(localized: "Status", table: "BackgroundAgentTask"), width: 80)
            tableColumn(String(localized: "Instruction", table: "BackgroundAgentTask"), width: nil)
            tableColumn(String(localized: "Created At", table: "BackgroundAgentTask"), width: 90)
            tableColumn(String(localized: "Started At", table: "BackgroundAgentTask"), width: 90)
            tableColumn(String(localized: "Finished At", table: "BackgroundAgentTask"), width: 90)
            tableColumn(String(localized: "Duration", table: "BackgroundAgentTask"), width: 55, alignment: .trailing)
            tableColumn(String(localized: "Actions", table: "BackgroundAgentTask"), width: 40, alignment: .center)
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
                    // 状态列
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
                        .frame(width: 90, alignment: .leading)

                    // 开始时间列
                    Text(task.startedAt.map { shortTime($0) } ?? "-")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .frame(width: 90, alignment: .leading)

                    // 完成时间列
                    Text(task.finishedAt.map { shortTime($0) } ?? "-")
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .frame(width: 90, alignment: .leading)

                    // 耗时列
                    Text(durationText(task: task))
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .frame(width: 55, alignment: .trailing)

                    // 操作列
                    AppIconButton(
                        systemImage: "xmark",
                        tint: AppUI.Color.semantic.textTertiary,
                        action: { deleteTask(task) }
                    )
                    .frame(width: 40, alignment: .center)
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
            GlassKeyValueRow(
                label: String(localized: "Full Instruction", table: "BackgroundAgentTask"),
                value: task.originalPrompt
            )

            // 执行结果或错误信息
            if let summary = task.resultSummary, !summary.isEmpty {
                GlassKeyValueRow(
                    label: String(localized: "Result", table: "BackgroundAgentTask"),
                    value: summary
                )
            } else if let error = task.errorDescription, !error.isEmpty {
                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                    Text(String(localized: "Error Message", table: "BackgroundAgentTask"))
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

            Text(paginationText)
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
        let label: String = switch status {
        case .pending: String(localized: "Pending", table: "BackgroundAgentTask")
        case .running: String(localized: "Running", table: "BackgroundAgentTask")
        case .succeeded: String(localized: "Completed", table: "BackgroundAgentTask")
        case .failed: String(localized: "Failed", table: "BackgroundAgentTask")
        }
        let fgColor: Color = switch style {
        case .warning: AppUI.Color.semantic.warning
        case .info: AppUI.Color.semantic.info
        case .success: AppUI.Color.semantic.success
        case .error: AppUI.Color.semantic.error
        default: AppUI.Color.semantic.textSecondary
        }
        let bgColor = fgColor.opacity(0.15)
        return Text(label)
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(fgColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
                    .stroke(fgColor.opacity(0.2), lineWidth: 1)
            )
            .cornerRadius(DesignTokens.Radius.full)
    }

    private var paginationText: String {
        let totalStr = String(localized: "Total: %lld", table: "BackgroundAgentTask")
            .replacingOccurrences(of: "%lld", with: "\(total)")
        let pageStr = String(localized: "Page %lld / %lld", table: "BackgroundAgentTask")
            .replacingOccurrences(of: "%lld", with: "\(currentPage)")
            .replacingOccurrences(of: "%lld", with: "\(totalPages)")
        return "\(totalStr) · \(pageStr)"
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
