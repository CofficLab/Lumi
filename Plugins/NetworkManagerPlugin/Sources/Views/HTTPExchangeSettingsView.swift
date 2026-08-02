import AppKit
import Foundation
import LumiUI
import SwiftUI

/// Bodies larger than this are shown as a download prompt instead of
/// being decoded and rendered inline, to avoid blocking the main thread.
private let largePayloadByteThreshold = 32 * 1024  // 32 KB

@MainActor
public struct HTTPExchangeSettingsView: View {
    private let store: HTTPExchangeStore
    @LumiTheme private var theme

    @State private var records: [HTTPExchangeRecord] = []
    @State private var isLoading = true
    @State private var isReloading = false
    @State private var isLoadingMore = false
    @State private var hasMoreRecords = true
    @State private var totalRecordCount: Int?
    @State private var selectedRecordID: UUID?
    @State private var dailyCountSeries = HTTPExchangeDailyCountSeries(points: [])
    @State private var exportErrorMessage: String?

    private let pageSize = 40

    public init(store: HTTPExchangeStore) {
        self.store = store
    }

    private var selectedRecord: HTTPExchangeRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("HTTP Exchange", bundle: .module),
            subtitle: LumiPluginLocalization.string("Inspect all HTTP requests and responses made by Lumi", bundle: .module),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Label(totalCountLabel, systemImage: "arrow.up.arrow.down.circle")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    AppButton(LumiPluginLocalization.string("Refresh", bundle: .module), systemImage: "arrow.clockwise", size: .small) {
                        Task { await reloadAsync() }
                    }
                    AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", size: .small) {
                        NSWorkspace.shared.open(store.directory)
                    }
                }

                requestActivity

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: .infinity)
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
        .alert(
            LumiPluginLocalization.string("Export failed", bundle: .module),
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button(LumiPluginLocalization.string("OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
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

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading && records.isEmpty {
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
                                .onAppear {
                                    if record.id == records.last?.id {
                                        Task { await loadMoreAsync() }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)

                if isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.bottom, 8)
                }
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
                    Text(formattedDate(record.startedAt))
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
            } export: {
                export(record: selectedRecord)
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

            payloadSection(
                title: LumiPluginLocalization.string("Request Headers", bundle: .module),
                subtitle: LumiPluginLocalization.string("Raw header fields sent with the request", bundle: .module),
                data: record.requestHeadersJSON,
                fallback: "{}"
            )
            payloadSection(
                title: LumiPluginLocalization.string("Request Body", bundle: .module),
                subtitle: String(format: LumiPluginLocalization.string("Original request body bytes (%@)", bundle: .module), byteCount(record.requestBody)),
                data: record.requestBody,
                fallback: "<empty>",
                bodyKind: .request,
                recordID: record.id,
                mimeType: nil,
                dataDirectory: store.directory
            )
            payloadSection(
                title: LumiPluginLocalization.string("Request Options", bundle: .module),
                subtitle: LumiPluginLocalization.string("URLRequest transport options captured at send time", bundle: .module),
                data: record.requestDetailsJSON,
                fallback: "{}"
            )
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

            payloadSection(
                title: LumiPluginLocalization.string("Response Headers", bundle: .module),
                subtitle: LumiPluginLocalization.string("Raw header fields received from the server", bundle: .module),
                data: record.responseHeadersJSON,
                fallback: "<no response headers>"
            )
            payloadSection(
                title: LumiPluginLocalization.string("Response Body", bundle: .module),
                subtitle: String(format: LumiPluginLocalization.string("Original response body bytes (%@)", bundle: .module), byteCount(record.responseBody)),
                data: record.responseBody,
                fallback: "<empty>",
                bodyKind: .response,
                recordID: record.id,
                mimeType: record.responseMIMEType,
                dataDirectory: store.directory
            )
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
                        HTTPExchangePayloadView(data: details, fallback: "{}")
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

    /// Renders a simple payload section with the normal inline renderer.
    /// Used for headers and options which are always small.
    @ViewBuilder
    private func payloadSection(
        title: String,
        subtitle: String,
        data: Data?,
        fallback: String
    ) -> some View {
        AppSettingsSection(title: title, subtitle: subtitle) {
            HTTPExchangePayloadView(data: data, fallback: fallback)
        }
    }

    /// Renders a payload section, routing to `HTTPExchangeLargePayloadView` when
    /// the data exceeds `largePayloadByteThreshold` to avoid expensive inline rendering.
    @ViewBuilder
    private func payloadSection(
        title: String,
        subtitle: String,
        data: Data?,
        fallback: String,
        bodyKind: HTTPExchangeLargePayloadView.BodyKind,
        recordID: UUID,
        mimeType: String?,
        dataDirectory: URL
    ) -> some View {
        AppSettingsSection(title: title, subtitle: subtitle) {
            if let data, data.count > largePayloadByteThreshold {
                HTTPExchangeLargePayloadView(
                    bodyKind: bodyKind,
                    bodyData: data,
                    mimeType: mimeType,
                    recordID: recordID,
                    dataDirectoryURL: dataDirectory
                )
            } else {
                HTTPExchangePayloadView(data: data, fallback: fallback)
            }
        }
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
        guard !isReloading else { return }
        isReloading = true
        isLoading = true
        defer {
            isReloading = false
            isLoading = false
        }
        await Task.yield()

        let loadedRecords = store.fetchPage(limit: pageSize)
        let total = store.count()
        let series = store.fetchDailyCountSeries()
        records = loadedRecords
        totalRecordCount = total
        dailyCountSeries = series
        hasMoreRecords = loadedRecords.count == pageSize
        if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = records.first?.id
        }
    }

    private func loadMoreAsync() async {
        guard !isLoading,
              !isLoadingMore,
              hasMoreRecords,
              let last = records.last else { return }

        isLoadingMore = true
        let page = store.fetchPage(
            limit: pageSize,
            beforeStartedAt: last.startedAt
        )
        records.append(contentsOf: page)
        hasMoreRecords = page.count == pageSize
        isLoadingMore = false
    }

    private var totalCountLabel: String {
        guard let totalRecordCount else {
            return LumiPluginLocalization.string("Loading...", bundle: .module)
        }
        return "\(totalRecordCount) " + LumiPluginLocalization.string("HTTP exchanges", bundle: .module)
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

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func export(record: HTTPExchangeRecord) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "http-exchange-\(record.id.uuidString.prefix(8)).md"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try HTTPExchangeExportFormatter.document(for: record)
                .write(to: url, atomically: true, encoding: .utf8)
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

@MainActor
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
    private let export: () -> Void
    @State private var selectedTab: DetailTab = .request

    init<Request: View, Response: View>(
        recordID: UUID,
        @ViewBuilder request: () -> Request,
        @ViewBuilder response: () -> Response,
        export: @escaping () -> Void
    ) {
        self.recordID = recordID
        self.request = AnyView(request())
        self.response = AnyView(response())
        self.export = export
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
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
                .frame(maxWidth: .infinity, alignment: .leading)

                AppButton(
                    LumiPluginLocalization.string("Export", bundle: .module),
                    systemImage: "square.and.arrow.down",
                    size: .small,
                    action: export
                )
            }
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
