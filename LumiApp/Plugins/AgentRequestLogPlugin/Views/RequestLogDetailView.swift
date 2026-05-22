import SwiftUI
import LumiUI

/// 请求日志详情视图 - 展示数据库原始数据
struct RequestLogDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: RequestLogBrowserViewModel

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Request Log", table: "RequestLog"),
            systemImage: "doc.text.magnifyingglass"
        ) {
            HStack(spacing: 12) {
                statsSummary

                GlassDivider()
                    .frame(height: 16)

                AppIconButton(systemImage: "arrow.clockwise") {
                    Task { await viewModel.reload() }
                }
                .help(String(localized: "Reload", table: "RequestLog"))
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                filterTabs

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(String(localized: "Loading...", table: "RequestLog"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else {
                    contentView
                }

                footer
            }
            .frame(minWidth: 912, minHeight: 512)
        }
        .task {
            await viewModel.reload()
        }
    }

    // MARK: - Header

    private var statsSummary: some View {
        HStack(spacing: 12) {
            StatusBarPopoverMetricBadge(
                label: String(localized: "Total", table: "RequestLog"),
                value: "\(viewModel.stats.totalRequests)",
                tint: theme.textSecondary
            )
            StatusBarPopoverMetricBadge(
                label: String(localized: "Success", table: "RequestLog"),
                value: "\(viewModel.stats.successCount)",
                tint: theme.success
            )
            StatusBarPopoverMetricBadge(
                label: String(localized: "Failed", table: "RequestLog"),
                value: "\(viewModel.stats.failedCount)",
                tint: theme.error
            )
            StatusBarPopoverMetricBadge(
                label: String(localized: "Avg", table: "RequestLog"),
                value: String(format: "%.1fs", viewModel.stats.averageDuration),
                tint: theme.textSecondary
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var filterTabs: some View {
        HStack(spacing: 0) {
            filterTab(
                title: String(localized: "All", table: "RequestLog"),
                icon: "list.bullet",
                filter: nil
            )

            filterTab(
                title: String(localized: "Success", table: "RequestLog"),
                icon: "checkmark.circle",
                filter: true
            )

            filterTab(
                title: String(localized: "Failed", table: "RequestLog"),
                icon: "xmark.circle",
                filter: false
            )
        }
        .frame(width: 360, height: 30)
        .padding(2)
        .appSurface(style: .subtle, cornerRadius: 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    private func filterTab(title: String, icon: String, filter: Bool?) -> some View {
        let isActive: Bool
        switch filter {
        case nil:
            isActive = viewModel.filterSuccess == nil
        case true:
            isActive = viewModel.filterSuccess == true
        case false:
            isActive = viewModel.filterSuccess == false
        }

        return Button {
            viewModel.filterSuccess = filter
            viewModel.currentPage = 1
            Task { await viewModel.reload() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.appMicroEmphasized)
                Text(title)
                    .font(.appMicroEmphasized)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(isActive ? theme.primary.opacity(0.15) : Color.clear)
            .foregroundColor(isActive ? theme.primary : theme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if viewModel.items.isEmpty {
            emptyView
        } else {
            requestLogTable
        }
    }

    // MARK: - Table

    @ViewBuilder
    private var requestLogTable: some View {
        Table(viewModel.items) {
            TableColumn(String(localized: "Time", table: "RequestLog")) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.timestamp, style: .date)
                        .font(.appMicro)
                    Text(row.timestamp, style: .time)
                        .font(.appMicro)
                }
                .foregroundColor(theme.textPrimary)
            }
            .width(min: 108, max: 124)

            TableColumn(String(localized: "Method", table: "RequestLog")) { row in
                Text(row.method.uppercased())
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
            }
            .width(min: 56, max: 68)

            TableColumn(String(localized: "URL", table: "RequestLog")) { row in
                Text(row.requestURL)
                    .font(.appMicro)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(theme.textPrimary)
            }
            .width(min: 240)

            TableColumn(String(localized: "Body Size", table: "RequestLog")) { row in
                Text(formatBytes(row.requestBodySize))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
            .width(min: 76, max: 90)

            TableColumn(String(localized: "Status", table: "RequestLog")) { row in
                if let code = row.responseStatusCode {
                    Text("\(code)")
                        .font(.appMicroEmphasized)
                        .foregroundColor(statusColor(code: code))
                } else {
                    Text("--")
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 58, max: 72)

            TableColumn(String(localized: "Duration", table: "RequestLog")) { row in
                if let duration = row.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.appMicro)
                        .monospacedDigit()
                        .foregroundColor(theme.textPrimary)
                } else {
                    Text("--")
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 76, max: 90)

            TableColumn(String(localized: "Result", table: "RequestLog")) { row in
                if row.isSuccess {
                    Label(String(localized: "Success", table: "RequestLog"), systemImage: "checkmark.circle.fill")
                        .font(.appMicro)
                        .foregroundColor(theme.success)
                } else {
                    Label(String(localized: "Failed", table: "RequestLog"), systemImage: "xmark.circle.fill")
                        .font(.appMicro)
                        .foregroundColor(theme.error)
                }
            }
            .width(min: 82, max: 96)

            TableColumn(String(localized: "Error", table: "RequestLog")) { row in
                if let error = row.errorMessage {
                    Text(error)
                        .font(.appMicro)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(theme.error)
                } else {
                    Text("--")
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 160)

            TableColumn(String(localized: "Request ID", table: "RequestLog")) { row in
                Text(row.requestId.uuidString.prefix(8))
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }
            .width(min: 82, max: 96)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .controlSize(.small)
        .background(Color.clear)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text(
                String(
                    format: String(localized: "Showing: %d", table: "RequestLog"),
                    viewModel.totalDisplayCount
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            Spacer()

            AppButton(String(localized: "Prev", table: "RequestLog"), size: .small) {
                viewModel.previousPage()
            }
            .disabled(viewModel.currentPage <= 1)

            Text(
                String(
                    format: String(localized: "Page %d / %d", table: "RequestLog"),
                    viewModel.currentPage,
                    viewModel.totalPages
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            AppButton(String(localized: "Next", table: "RequestLog"), size: .small) {
                viewModel.nextPage()
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages)
        }
        .padding(.top, 8)
    }

    // MARK: - Empty

    private var emptyView: some View {
        AppEmptyState(
            icon: "tray",
            title: LocalizedStringKey(String(localized: "No request logs", table: "RequestLog"))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    private func statusColor(code: Int) -> Color {
        if code >= 200 && code < 300 {
            return theme.success
        } else if code >= 400 {
            return theme.error
        } else {
            return theme.textSecondary
        }
    }
}
