import SwiftUI
import LumiUI

/// 请求日志详情视图 - 展示数据库原始数据
public struct RequestLogDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: RequestLogBrowserViewModel

    public var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Request Log", bundle: .module),
            systemImage: "doc.text.magnifyingglass"
        ) {
            HStack(spacing: 12) {
                statsSummary

                GlassDivider()
                    .frame(height: 16)

                AppIconButton(systemImage: "arrow.clockwise") {
                    Task { await viewModel.reload() }
                }
                .help(String(localized: "Reload", bundle: .module))
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                filterTabs

                if viewModel.isLoading {
                    Spacer()
                    ProgressView(String(localized: "Loading...", bundle: .module))
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
                label: String(localized: "Total", bundle: .module),
                value: "\(viewModel.stats.totalRequests)",
                tint: theme.textSecondary
            )
            StatusBarPopoverMetricBadge(
                label: String(localized: "Success", bundle: .module),
                value: "\(viewModel.stats.successCount)",
                tint: theme.success
            )
            StatusBarPopoverMetricBadge(
                label: String(localized: "Failed", bundle: .module),
                value: "\(viewModel.stats.failedCount)",
                tint: theme.error
            )
            StatusBarPopoverMetricBadge(
                label: String(localized: "Avg", bundle: .module),
                value: String(format: "%.1fs", viewModel.stats.averageDuration),
                tint: theme.textSecondary
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var filterTabs: some View {
        HStack(spacing: 0) {
            filterTab(
                title: String(localized: "All", bundle: .module),
                icon: "list.bullet",
                filter: nil
            )

            filterTab(
                title: String(localized: "Success", bundle: .module),
                icon: "checkmark.circle",
                filter: true
            )

            filterTab(
                title: String(localized: "Failed", bundle: .module),
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
            viewModel.setFilterSuccess(filter)
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
            TableColumn(String(localized: "Time", bundle: .module)) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.timestamp, style: .date)
                        .font(.appMicro)
                    Text(row.timestamp, style: .time)
                        .font(.appMicro)
                }
                .foregroundColor(theme.textPrimary)
            }
            .width(min: 108, max: 124)

            TableColumn(String(localized: "Method", bundle: .module)) { row in
                Text(row.method.uppercased())
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
            }
            .width(min: 56, max: 68)

            TableColumn(String(localized: "URL", bundle: .module)) { row in
                Text(row.requestURL)
                    .font(.appMicro)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(theme.textPrimary)
            }
            .width(min: 240)

            TableColumn(String(localized: "Body Size", bundle: .module)) { row in
                Text(formatBytes(row.requestBodySize))
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
            .width(min: 76, max: 90)

            TableColumn(String(localized: "Status", bundle: .module)) { row in
                if let code = row.responseStatusCode {
                    Text("\(code)")
                        .font(.appMicroEmphasized)
                        .foregroundColor(statusColor(code: code))
                } else {
                    Text("--", bundle: .module)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 58, max: 72)

            TableColumn(String(localized: "Duration", bundle: .module)) { row in
                if let duration = row.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.appMicro)
                        .monospacedDigit()
                        .foregroundColor(theme.textPrimary)
                } else {
                    Text("--", bundle: .module)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 76, max: 90)

            TableColumn(String(localized: "Result", bundle: .module)) { row in
                if row.isSuccess {
                    Label(String(localized: "Success", bundle: .module), systemImage: "checkmark.circle.fill")
                        .font(.appMicro)
                        .foregroundColor(theme.success)
                } else {
                    Label(String(localized: "Failed", bundle: .module), systemImage: "xmark.circle.fill")
                        .font(.appMicro)
                        .foregroundColor(theme.error)
                }
            }
            .width(min: 82, max: 96)

            TableColumn(String(localized: "Response Body", bundle: .module)) { row in
                if let preview = row.responseBodyPreview {
                    Text(preview)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(theme.textPrimary)
                } else if let size = row.responseBodySize {
                    Text(formatBytes(size))
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                } else {
                    Text("--", bundle: .module)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 140)

            TableColumn(String(localized: "Error", bundle: .module)) { row in
                if let error = row.errorMessage {
                    Text(error)
                        .font(.appMicro)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(theme.error)
                } else {
                    Text("--", bundle: .module)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .width(min: 160)

            TableColumn(String(localized: "Request ID", bundle: .module)) { row in
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
                    format: String(localized: "Showing: %d", bundle: .module),
                    viewModel.totalDisplayCount
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            Spacer()

            AppButton(String(localized: "Prev", bundle: .module), size: .small) {
                viewModel.previousPage()
            }
            .disabled(viewModel.currentPage <= 1)

            Text(
                String(
                    format: String(localized: "Page %d / %d", bundle: .module),
                    viewModel.currentPage,
                    viewModel.totalPages
                )
            )
            .font(.appMicro)
            .foregroundColor(theme.textSecondary)

            AppButton(String(localized: "Next", bundle: .module), size: .small) {
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
            title: LocalizedStringKey(String(localized: "No request logs", bundle: .module))
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

    private func formatBytes(_ bytes: Int?) -> String {
        guard let bytes else { return "--" }
        return formatBytes(bytes)
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
