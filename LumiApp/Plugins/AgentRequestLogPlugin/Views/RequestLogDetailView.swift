import SwiftUI
import LumiUI

/// 请求日志详情视图 - 展示数据库原始数据
struct RequestLogDetailView: View {
    @ObservedObject var viewModel: RequestLogBrowserViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var separatorColor: Color {
        Color.adaptive(light: "D8D8DF", dark: "3A4649")
    }

    private var panelBackground: Color {
        Color.adaptive(light: "F7F7FA", dark: "1B2A2D")
    }

    private var controlBackground: Color {
        Color.adaptive(light: "ECECF2", dark: "243437")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

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
        .frame(minWidth: 960, minHeight: 560)
        .background(panelBackground)
        .task {
            await viewModel.reload()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                Text(String(localized: "Request Log", table: "RequestLog"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                // Stats summary
                HStack(spacing: 12) {
                    statBadge(
                        label: String(localized: "Total", table: "RequestLog"),
                        value: "\(viewModel.stats.totalRequests)",
                        color: Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
                    )
                    statBadge(
                        label: String(localized: "Success", table: "RequestLog"),
                        value: "\(viewModel.stats.successCount)",
                        color: .green
                    )
                    statBadge(
                        label: String(localized: "Failed", table: "RequestLog"),
                        value: "\(viewModel.stats.failedCount)",
                        color: .red
                    )
                    statBadge(
                        label: String(localized: "Avg", table: "RequestLog"),
                        value: String(format: "%.1fs", viewModel.stats.averageDuration),
                        color: Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
                    )
                }
                .fixedSize(horizontal: true, vertical: false)

                GlassDivider()
                    .frame(height: 16)

                // Reload button
                Button {
                    Task { await viewModel.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                }
                .buttonStyle(.plain)
                .help(String(localized: "Reload", table: "RequestLog"))
            }
            .frame(height: 24)

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
            .background(controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            separatorColor.frame(height: 1)
        }
    }

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Color.adaptive(light: "8E8E9F", dark: "9898A8"))
        }
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
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(isActive ? Color.accentColor.opacity(colorScheme == .light ? 0.14 : 0.22) : Color.clear)
            .foregroundColor(isActive ? Color.accentColor : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
                        .font(.system(size: 10))
                    Text(row.timestamp, style: .time)
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            }
            .width(min: 108, max: 124)

            TableColumn(String(localized: "Method", table: "RequestLog")) { row in
                Text(row.method.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            }
            .width(min: 56, max: 68)

            TableColumn(String(localized: "URL", table: "RequestLog")) { row in
                Text(row.requestURL)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            }
            .width(min: 240)

            TableColumn(String(localized: "Body Size", table: "RequestLog")) { row in
                Text(formatBytes(row.requestBodySize))
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
            .width(min: 76, max: 90)

            TableColumn(String(localized: "Status", table: "RequestLog")) { row in
                if let code = row.responseStatusCode {
                    Text("\(code)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusColor(code: code))
                } else {
                    Text("--")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "8E8E9F", dark: "9898A8"))
                }
            }
            .width(min: 58, max: 72)

            TableColumn(String(localized: "Duration", table: "RequestLog")) { row in
                if let duration = row.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                } else {
                    Text("--")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "8E8E9F", dark: "9898A8"))
                }
            }
            .width(min: 76, max: 90)

            TableColumn(String(localized: "Result", table: "RequestLog")) { row in
                if row.isSuccess {
                    Label(String(localized: "Success", table: "RequestLog"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                } else {
                    Label(String(localized: "Failed", table: "RequestLog"), systemImage: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            }
            .width(min: 82, max: 96)

            TableColumn(String(localized: "Error", table: "RequestLog")) { row in
                if let error = row.errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.red)
                } else {
                    Text("--")
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "8E8E9F", dark: "9898A8"))
                }
            }
            .width(min: 160)

            TableColumn(String(localized: "Request ID", table: "RequestLog")) { row in
                Text(row.requestId.uuidString.prefix(8))
                    .font(.system(size: 9))
                    .foregroundColor(Color.adaptive(light: "8E8E9F", dark: "9898A8"))
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
            .font(.system(size: 11))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Spacer()

            Button(String(localized: "Prev", table: "RequestLog")) {
                viewModel.previousPage()
            }
            .font(.system(size: 11))
            .disabled(viewModel.currentPage <= 1)

            Text(
                String(
                    format: String(localized: "Page %d / %d", table: "RequestLog"),
                    viewModel.currentPage,
                    viewModel.totalPages
                )
            )
            .font(.system(size: 11))
            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Button(String(localized: "Next", table: "RequestLog")) {
                viewModel.nextPage()
            }
            .font(.system(size: 11))
            .disabled(viewModel.currentPage >= viewModel.totalPages)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            separatorColor.frame(height: 1)
        }
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
            return .green
        } else if code >= 400 {
            return .red
        } else {
            return Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
        }
    }
}
