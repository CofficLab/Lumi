import AppKit
import Foundation
import LumiUI
import SwiftUI

@MainActor
public struct HTTPExchangeSettingsView: View {
    private let store: HTTPExchangeStore
    @LumiTheme private var theme

    @State private var records: [HTTPExchangeRecord] = []
    @State private var isLoading = true
    @State private var selectedRecordID: UUID?
    @State private var selectedDetailTab: DetailTab = .request

    private enum DetailTab: Hashable {
        case request
        case response
    }

    public init(store: HTTPExchangeStore) {
        self.store = store
    }

    private var selectedRecord: HTTPExchangeRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    private var dailyCountSeries: HTTPExchangeDailyCountSeries {
        HTTPExchangeDailyCountSeries.build(records: records)
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                header

                requestActivity

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 560, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            await reloadAsync()
        }
        .onReceive(NotificationCenter.default.publisher(for: HTTPExchangeStore.didChangeNotification)) { _ in
            Task { await reloadAsync() }
        }
    }

    private var requestActivity: some View {
        AppSettingsSection(title: "Request Activity", subtitle: "HTTP requests per day over the last 14 days", spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Daily HTTP requests", systemImage: "chart.xyaxis.line")
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Text("Peak (dailyCountSeries.peakCount)")
                        .font(.appMicro)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                HTTPExchangeDailyCountChart(series: dailyCountSeries)
                    .frame(height: 132)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.divider, lineWidth: 0.5)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("\(records.count) HTTP exchanges", systemImage: "arrow.up.arrow.down.circle")
            if let selectedRecord {
                Text("Selected: \(selectedRecord.requestMethod) \(selectedRecord.requestURL)")
                    .lineLimit(1)
            }
            Spacer()
            AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                Task { await reloadAsync() }
            }
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                NSWorkspace.shared.open(store.directory)
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                AppEmptyState(
                    icon: "arrow.up.arrow.down.circle",
                    title: "No HTTP exchanges"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(records) { record in
                            recordRow(record)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func recordRow(_ record: HTTPExchangeRecord) -> some View {
        let isSelected = selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedRecordID = record.id
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.requestMethod)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Text(statusText(for: record))
                        .font(.appMicro)
                        .foregroundStyle(statusColor(for: record))
                    Spacer(minLength: 0)
                    Text(relativeDate(record.startedAt))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(record.requestURL)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRecord {
            TabView(selection: $selectedDetailTab) {
                requestTab(for: selectedRecord)
                    .tabItem { Label("Request", systemImage: "arrow.up.right") }
                    .tag(DetailTab.request)

                responseTab(for: selectedRecord)
                    .tabItem { Label("Response", systemImage: "arrow.down.left") }
                    .tag(DetailTab.response)
            }
        } else {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: "Select an HTTP exchange"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func requestTab(for record: HTTPExchangeRecord) -> some View {
        detailScroll {
            AppSettingsSection(title: "Request", subtitle: "HTTP request sent by the client") {
                VStack(spacing: 0) {
                    detailRow(title: "Method", icon: "arrow.left.arrow.right", value: record.requestMethod)
                    AppSettingsDivider()
                    detailRow(title: "URL", icon: "link", value: record.requestURL, monospace: true)
                    AppSettingsDivider()
                    detailRow(title: "Started At", icon: "calendar", value: formattedDate(record.startedAt))
                    if let duration = record.duration {
                        AppSettingsDivider()
                        detailRow(title: "Duration", icon: "clock", value: String(format: "%.3f s", duration))
                    }
                }
            }

            payloadSection(title: "Request Headers", subtitle: "Raw header fields sent with the request", data: record.requestHeadersJSON, fallback: "{}")
            payloadSection(title: "Request Body", subtitle: "Original request body bytes (\(byteCount(record.requestBody)))", data: record.requestBody, fallback: "<empty>")
            payloadSection(title: "Request Options", subtitle: "URLRequest transport options captured at send time", data: record.requestDetailsJSON, fallback: "{}")
        }
    }

    private func responseTab(for record: HTTPExchangeRecord) -> some View {
        detailScroll {
            AppSettingsSection(title: "Response", subtitle: "HTTP response received from the server") {
                VStack(spacing: 0) {
                    detailRow(title: "Status", icon: "number", value: statusText(for: record))
                    if let responseURL = record.responseURL {
                        AppSettingsDivider()
                        detailRow(title: "URL", icon: "link", value: responseURL, monospace: true)
                    }
                    if let version = record.responseHTTPVersion {
                        AppSettingsDivider()
                        detailRow(title: "HTTP Version", icon: "globe", value: version)
                    }
                    if let mimeType = record.responseMIMEType {
                        AppSettingsDivider()
                        detailRow(title: "MIME Type", icon: "doc.text", value: mimeType)
                    }
                }
            }

            payloadSection(title: "Response Headers", subtitle: "Raw header fields received from the server", data: record.responseHeadersJSON, fallback: "<no response headers>")
            payloadSection(title: "Response Body", subtitle: "Original response body bytes (\(byteCount(record.responseBody)))", data: record.responseBody, fallback: "<empty>")
            errorSection(for: record)
        }
    }

    @ViewBuilder
    private func errorSection(for record: HTTPExchangeRecord) -> some View {
        if record.errorDescription != nil {
            AppSettingsSection(title: "Error", subtitle: "Transport or HTTP failure details") {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorDescription = record.errorDescription {
                        Text(errorDescription)
                            .foregroundStyle(theme.textPrimary)
                    }
                    if let domain = record.errorDomain, let code = record.errorCode {
                        Text("\(domain) (\(code))")
                            .font(.appCaption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    if let details = record.errorDetailsJSON {
                        codeBlock(prettyJSON(details))
                    }
                }
            }
        }
    }

    private func detailScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(20)
        }
    }

    private func payloadSection(title: String, subtitle: String, data: Data?, fallback: String) -> some View {
        AppSettingsSection(title: title, subtitle: subtitle) {
            codeBlock(data.map(payloadText) ?? fallback)
        }
    }

    private func codeBlock(_ text: String) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minHeight: 70, maxHeight: 260)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: icon)
                .frame(width: 130, alignment: .leading)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .appCaption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reloadAsync() async {
        // Use withCheckedContinuation to "yield" control back to SwiftUI,
        // allowing the view to render the loading state first.
        await withCheckedContinuation { continuation in
            // The synchronous fetchAll() will run after SwiftUI renders
            let loadedRecords = store.fetchAll()
            records = loadedRecords
            if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
                selectedRecordID = records.first?.id
            }
            isLoading = false
            continuation.resume()
        }
    }

    private func statusText(for record: HTTPExchangeRecord) -> String {
        if let statusCode = record.responseStatusCode { return String(statusCode) }
        return record.errorDescription == nil ? "Pending" : "Error"
    }

    private func statusColor(for record: HTTPExchangeRecord) -> Color {
        guard let statusCode = record.responseStatusCode else {
            return record.errorDescription == nil ? theme.textSecondary : .red
        }
        return (200..<300).contains(statusCode) ? .green : .orange
    }

    private func byteCount(_ data: Data?) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(data?.count ?? 0), countStyle: .binary)
    }

    private func payloadText(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let pretty = String(data: prettyData, encoding: .utf8) {
            return pretty
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private func prettyJSON(_ data: Data) -> String {
        payloadText(data)
    }

    private func relativeDate(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
