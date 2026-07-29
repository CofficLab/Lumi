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
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("HTTP Exchange", bundle: .module),
            subtitle: LumiPluginLocalization.string("Inspect all HTTP requests and responses made by Lumi", bundle: .module),
            showHeader: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
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
        }
        .task {
            await reloadAsync()
        }
        .onReceive(NotificationCenter.default.publisher(for: HTTPExchangeStore.didChangeNotification)) { _ in
            Task { await reloadAsync() }
        }
    }

    private var requestActivity: some View {
        AppSettingsSection(title: LumiPluginLocalization.string("Request Activity", bundle: .module), subtitle: LumiPluginLocalization.string("HTTP requests per day over the last 14 days", bundle: .module), spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Label(LumiPluginLocalization.string("Daily HTTP requests", bundle: .module), systemImage: "chart.xyaxis.line")
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Text(LumiPluginLocalization.string("Peak", bundle: .module) + " (\(dailyCountSeries.peakCount))")
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

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Label("\(records.count) " + LumiPluginLocalization.string("HTTP exchanges", bundle: .module), systemImage: "arrow.up.arrow.down.circle")
            Spacer()
            AppButton(LumiPluginLocalization.string("Refresh", bundle: .module), systemImage: "arrow.clockwise", size: .small) {
                Task { await reloadAsync() }
            }
            AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", size: .small) {
                NSWorkspace.shared.open(store.directory)
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.background)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                AppEmptyState(
                    icon: "arrow.up.arrow.down.circle",
                    title: LumiPluginLocalization.string("No HTTP exchanges", bundle: .module)
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
            HTTPExchangeDetailView(recordID: selectedRecord.id) {
                requestTab(for: selectedRecord)
            } response: {
                responseTab(for: selectedRecord)
            }
        } else {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: LumiPluginLocalization.string("Select an HTTP exchange", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func requestTab(for record: HTTPExchangeRecord) -> some View {
        detailScroll {
            AppSettingsSection(title: LumiPluginLocalization.string("Request", bundle: .module), subtitle: LumiPluginLocalization.string("HTTP request sent by the client", bundle: .module)) {
                VStack(spacing: 0) {
                    detailRow(title: LumiPluginLocalization.string("Method", bundle: .module), icon: "arrow.left.arrow.right", value: record.requestMethod)
                    AppSettingsDivider()
                    detailRow(title: LumiPluginLocalization.string("URL", bundle: .module), icon: "link", value: record.requestURL, monospace: true)
                    AppSettingsDivider()
                    detailRow(title: LumiPluginLocalization.string("Started At", bundle: .module), icon: "calendar", value: formattedDate(record.startedAt))
                    if let duration = record.duration {
                        AppSettingsDivider()
                        detailRow(title: LumiPluginLocalization.string("Duration", bundle: .module), icon: "clock", value: String(format: "%.3f s", duration))
                    }
                }
            }

            payloadSection(title: LumiPluginLocalization.string("Request Headers", bundle: .module), subtitle: LumiPluginLocalization.string("Raw header fields sent with the request", bundle: .module), data: record.requestHeadersJSON, fallback: "{}")
            payloadSection(title: LumiPluginLocalization.string("Request Body", bundle: .module), subtitle: String(format: LumiPluginLocalization.string("Original request body bytes (%@)", bundle: .module), byteCount(record.requestBody)), data: record.requestBody, fallback: "<empty>")
            payloadSection(title: LumiPluginLocalization.string("Request Options", bundle: .module), subtitle: LumiPluginLocalization.string("URLRequest transport options captured at send time", bundle: .module), data: record.requestDetailsJSON, fallback: "{}")
        }
    }

    private func responseTab(for record: HTTPExchangeRecord) -> some View {
        detailScroll {
            AppSettingsSection(title: LumiPluginLocalization.string("Response", bundle: .module), subtitle: LumiPluginLocalization.string("HTTP response received from the server", bundle: .module)) {
                VStack(spacing: 0) {
                    detailRow(title: LumiPluginLocalization.string("Status", bundle: .module), icon: "number", value: statusText(for: record))
                    if let responseURL = record.responseURL {
                        AppSettingsDivider()
                        detailRow(title: LumiPluginLocalization.string("URL", bundle: .module), icon: "link", value: responseURL, monospace: true)
                    }
                    if let version = record.responseHTTPVersion {
                        AppSettingsDivider()
                        detailRow(title: LumiPluginLocalization.string("HTTP Version", bundle: .module), icon: "globe", value: version)
                    }
                    if let mimeType = record.responseMIMEType {
                        AppSettingsDivider()
                        detailRow(title: LumiPluginLocalization.string("MIME Type", bundle: .module), icon: "doc.text", value: mimeType)
                    }
                }
            }

            payloadSection(title: LumiPluginLocalization.string("Response Headers", bundle: .module), subtitle: LumiPluginLocalization.string("Raw header fields received from the server", bundle: .module), data: record.responseHeadersJSON, fallback: "<no response headers>")
            payloadSection(title: LumiPluginLocalization.string("Response Body", bundle: .module), subtitle: String(format: LumiPluginLocalization.string("Original response body bytes (%@)", bundle: .module), byteCount(record.responseBody)), data: record.responseBody, fallback: "<empty>")
            errorSection(for: record)
        }
    }

    @ViewBuilder
    private func errorSection(for record: HTTPExchangeRecord) -> some View {
        if record.errorDescription != nil {
            AppSettingsSection(title: LumiPluginLocalization.string("Error", bundle: .module), subtitle: LumiPluginLocalization.string("Transport or HTTP failure details", bundle: .module)) {
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
        return record.errorDescription == nil ? LumiPluginLocalization.string("Pending", bundle: .module) : LumiPluginLocalization.string("Error", bundle: .module)
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

private struct HTTPExchangeDetailView: View {
    private enum DetailTab: String {
        case request
        case response

        var title: String {
            switch self {
            case .request:
                LumiPluginLocalization.string("Request", bundle: .module)
            case .response:
                LumiPluginLocalization.string("Response", bundle: .module)
            }
        }

        var icon: String {
            switch self {
            case .request: "arrow.up.right"
            case .response: "arrow.down.left"
            }
        }
    }

    let recordID: UUID
    private let request: AnyView
    private let response: AnyView
    @State private var selectedTab: DetailTab = .request

    init<Request: View, Response: View>(
        recordID: UUID,
        @ViewBuilder request: () -> Request,
        @ViewBuilder response: () -> Response
    ) {
        self.recordID = recordID
        self.request = AnyView(request())
        self.response = AnyView(response())
    }

    var body: some View {
        VStack(spacing: 0) {
            AppTabBar(
                tabs: [
                    AppTabBar.Tab(title: DetailTab.request.title, icon: DetailTab.request.icon, id: DetailTab.request.rawValue),
                    AppTabBar.Tab(title: DetailTab.response.title, icon: DetailTab.response.icon, id: DetailTab.response.rawValue),
                ],
                selectedTab: Binding(
                    get: { selectedTab.rawValue },
                    set: { selectedTab = DetailTab(rawValue: $0) ?? .request }
                )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            AppDivider()

            Group {
                switch selectedTab {
                case .request:
                    request
                case .response:
                    response
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .id(recordID)
    }
}
