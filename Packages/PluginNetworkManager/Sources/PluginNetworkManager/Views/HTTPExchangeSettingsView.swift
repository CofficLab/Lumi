import AppKit
import Foundation
import LumiUI
import SwiftUI

/// Bodies larger than this are shown as a download prompt instead of
/// being decoded and rendered inline, to avoid blocking the main thread.
private let largePayloadByteThreshold = 32 * 1024  // 32 KB

@MainActor
public struct HTTPExchangeSettingsView: View {
    private enum LogFilter: String, CaseIterable {
        case all
        case normal
        case abnormal

        var title: String {
            switch self {
            case .all:
                LumiPluginLocalization.string("All", bundle: .module)
            case .normal:
                LumiPluginLocalization.string("Normal", bundle: .module)
            case .abnormal:
                LumiPluginLocalization.string("Abnormal", bundle: .module)
            }
        }
    }

    enum TimeRangeFilter: String, CaseIterable {
        case all
        case today
        case lastHour
        case lastTenMinutes

        var title: String {
            switch self {
            case .all:
                LumiPluginLocalization.string("All", bundle: .module)
            case .today:
                LumiPluginLocalization.string("Today", bundle: .module)
            case .lastHour:
                LumiPluginLocalization.string("Last Hour", bundle: .module)
            case .lastTenMinutes:
                LumiPluginLocalization.string("Last 10 Minutes", bundle: .module)
            }
        }

        /// Earliest allowed `startedAt`; `nil` means no time filter.
        func cutOff(relativeTo now: Date = Date()) -> Date? {
            switch self {
            case .all:
                return nil
            case .today:
                return Calendar.current.startOfDay(for: now)
            case .lastHour:
                return now.addingTimeInterval(-3600)
            case .lastTenMinutes:
                return now.addingTimeInterval(-600)
            }
        }
    }

    private let store: HTTPExchangeStore
    @LumiTheme private var theme

    @State private var records: [HTTPExchangeListSnapshot] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMoreRecords = true
    @State private var nextPageCursor: Date?
    @State private var totalRecordCount: Int?
    @State private var isTotalCountPopoverPresented = false
    @State private var selectedRecordID: UUID?
    @State private var selectedDetail: HTTPExchangeExportSnapshot?
    @State private var reloadGeneration = 0
    @State private var selectedFilter: LogFilter = .all
    @State private var selectedDomain: String?
    @State private var selectedTimeRange: TimeRangeFilter = .all
    @State private var domains: [String] = []
    @State private var dailyCountSeries = HTTPExchangeDailyCountSeries(points: [])
    @State private var exportErrorMessage: String?

    private let pageSize = 40

    public init(store: HTTPExchangeStore) {
        self.store = store
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
                    totalCountButton
                    AppButton(LumiPluginLocalization.string("Refresh", bundle: .module), systemImage: "arrow.clockwise", size: .small) {
                        Task { await reloadAsync() }
                    }
#if DEBUG
                    AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", size: .small) {
                        NSWorkspace.shared.open(store.directory)
                    }
#endif
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
        .onChange(of: selectedDomain) { _, _ in
            Task { await reloadAsync() }
        }
        .onChange(of: selectedFilter) { _, _ in
            Task { await reloadAsync() }
        }
        .onChange(of: selectedTimeRange) { _, _ in
            Task { await reloadAsync() }
        }
        .onChange(of: HTTPExportProgress.shared.errorMessage) { _, newValue in
            if let newValue {
                exportErrorMessage = newValue
            }
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

    private var sidebar: some View {
        VStack(spacing: 0) {
            filterTabs
            domainFilter
            timeRangeFilter
            AppDivider()

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
                    title: LumiPluginLocalization.string("No matching HTTP exchanges", bundle: .module)
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

    private var filterTabs: some View {
        AppTabBar(
            tabs: LogFilter.allCases.map {
                AppTabBar.Tab(title: $0.title, id: $0.rawValue)
            },
            selectedTab: Binding(
                get: { selectedFilter.rawValue },
                set: { newValue in
                    guard let filter = LogFilter(rawValue: newValue), filter != selectedFilter else { return }
                    selectedFilter = filter
                    selectedRecordID = nil
                    selectedDetail = nil
                }
            )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var domainFilter: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            Picker(LumiPluginLocalization.string("Domain", bundle: .module), selection: $selectedDomain) {
                Text(LumiPluginLocalization.string("All", bundle: .module)).tag(String?.none)
                ForEach(domains, id: \.self) { domain in
                    Text(domain).tag(String?.some(domain))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            if selectedDomain != nil {
                AppButton(
                    LumiPluginLocalization.string("Export", bundle: .module),
                    systemImage: "square.and.arrow.down",
                    size: .small
                ) {
                    exportFilteredLogs()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeRangeFilter: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
            Picker(LumiPluginLocalization.string("Time Range", bundle: .module), selection: $selectedTimeRange) {
                ForEach(TimeRangeFilter.allCases, id: \.self) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recordRow(_ record: HTTPExchangeListSnapshot) -> some View {
        let isSelected = selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedRecordID = record.id
            selectedDetail = nil
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.method)
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

                Text(record.url)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let selectedDetail {
                HTTPExchangeDetailView(recordID: selectedDetail.id) {
                    requestTab(for: selectedDetail)
                } response: {
                    responseTab(for: selectedDetail)
                } export: {
                    export(record: selectedDetail)
                }
            } else if selectedRecordID != nil {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                AppEmptyState(
                    icon: "doc.text.magnifyingglass",
                    title: LumiPluginLocalization.string("Select an HTTP exchange", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: selectedRecordID) {
            await loadSelectedDetailAsync()
        }
    }

    private func requestTab(for record: HTTPExchangeExportSnapshot) -> some View {
        detailScroll {
            AppSettingsSection(title: LumiPluginLocalization.string("Request", bundle: .module), subtitle: LumiPluginLocalization.string("HTTP request sent by the client", bundle: .module)) {
                AppMetadataCard {
                    AppMetadataRow(title: LumiPluginLocalization.string("Method", bundle: .module), systemImage: "arrow.left.arrow.right") {
                        AppTag(record.method, systemImage: "arrow.up.right", style: .accent)
                    }
                    AppSettingsDivider()
                    AppMetadataRow(title: LumiPluginLocalization.string("URL", bundle: .module), systemImage: "link") {
                        metadataValue(record.url, monospace: true, copyable: true)
                    }
                    AppSettingsDivider()
                    AppMetadataRow(title: LumiPluginLocalization.string("Started At", bundle: .module), systemImage: "calendar") {
                        metadataValue(formattedDate(record.startedAt))
                    }
                    if let duration = record.duration {
                        AppSettingsDivider()
                        AppMetadataRow(title: LumiPluginLocalization.string("Duration", bundle: .module), systemImage: "clock") {
                            metadataValue(String(format: "%.3f s", duration))
                        }
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
                mimeType: nil
            )
            payloadSection(
                title: LumiPluginLocalization.string("Request Options", bundle: .module),
                subtitle: LumiPluginLocalization.string("URLRequest transport options captured at send time", bundle: .module),
                data: record.requestDetailsJSON,
                fallback: "{}"
            )
        }
    }

    private func responseTab(for record: HTTPExchangeExportSnapshot) -> some View {
        detailScroll {
            AppSettingsSection(title: LumiPluginLocalization.string("Response", bundle: .module), subtitle: LumiPluginLocalization.string("HTTP response received from the server", bundle: .module)) {
                AppMetadataCard {
                    AppMetadataRow(title: LumiPluginLocalization.string("Status", bundle: .module), systemImage: "number") {
                        AppTag(statusText(for: record), systemImage: statusIcon(for: record), style: .accent)
                    }
                    if let responseURL = record.responseURL {
                        AppSettingsDivider()
                        AppMetadataRow(title: LumiPluginLocalization.string("URL", bundle: .module), systemImage: "link") {
                            metadataValue(responseURL, monospace: true, copyable: true)
                        }
                    }
                    if let version = record.responseHTTPVersion {
                        AppSettingsDivider()
                        AppMetadataRow(title: LumiPluginLocalization.string("HTTP Version", bundle: .module), systemImage: "globe") {
                            metadataValue(version)
                        }
                    }
                    if let mimeType = record.responseMIMEType {
                        AppSettingsDivider()
                        AppMetadataRow(title: LumiPluginLocalization.string("MIME Type", bundle: .module), systemImage: "doc.text") {
                            metadataValue(mimeType)
                        }
                    }
                }
            }

            payloadSection(
                title: LumiPluginLocalization.string("Response Headers", bundle: .module),
                subtitle: LumiPluginLocalization.string("Raw header fields received from the server", bundle: .module),
                data: record.responseHeadersJSON,
                fallback: "<no response headers>"
            )
            responseBodySection(for: record)
            errorSection(for: record)
        }
    }

    @ViewBuilder
    private func errorSection(for record: HTTPExchangeExportSnapshot) -> some View {
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

    /// Response body section that detects JSON content and shows a tabbed
    /// view with "Raw" and "Parsed" options when applicable.
    @ViewBuilder
    private func responseBodySection(for record: HTTPExchangeExportSnapshot) -> some View {
        let isJSON = record.responseMIMEType?.contains("json") == true
        let isLargePayload = (record.responseBody?.count ?? 0) > largePayloadByteThreshold

        AppSettingsSection(
            title: LumiPluginLocalization.string("Response Body", bundle: .module),
            subtitle: String(format: LumiPluginLocalization.string("Original response body bytes (%@)", bundle: .module), byteCount(record.responseBody))
        ) {
            if isLargePayload {
                HTTPExchangeLargePayloadView(
                    bodyKind: .response,
                    bodyData: record.responseBody,
                    mimeType: record.responseMIMEType,
                    recordID: record.id
                )
            } else if isJSON {
                HTTPExchangeJSONBodyTabs(data: record.responseBody, fallback: "<empty>")
            } else {
                HTTPExchangePayloadView(data: record.responseBody, fallback: "<empty>")
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
        mimeType: String?
    ) -> some View {
        AppSettingsSection(title: title, subtitle: subtitle) {
            if let data, data.count > largePayloadByteThreshold {
                HTTPExchangeLargePayloadView(
                    bodyKind: bodyKind,
                    bodyData: data,
                    mimeType: mimeType,
                    recordID: recordID
                )
            } else {
                HTTPExchangePayloadView(data: data, fallback: fallback)
            }
        }
    }

    @ViewBuilder
    private func metadataValue(_ value: String, monospace: Bool = false, copyable: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(value)
                .font(monospace ? .appMonoCaption : .appBody)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .lineLimit(monospace ? 3 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if copyable {
                AppIconButton(systemImage: "doc.on.doc", size: .compact) {
                    LumiPasteboard.copyString(value)
                }
                .help(LumiPluginLocalization.string("Copy", bundle: .module))
            }
        }
    }

    private func statusIcon(for record: HTTPExchangeExportSnapshot) -> String {
        if record.responseStatusCode != nil {
            return "checkmark.circle"
        }
        return record.errorDescription == nil ? "clock" : "exclamationmark.triangle"
    }

    private func reloadAsync() async {
        reloadGeneration += 1
        let generation = reloadGeneration
        isLoading = true

        // Snapshot all query inputs on the main actor. The list query returns
        // metadata only; detail bodies and secondary statistics are loaded
        // independently after the first page is visible.
        let status = statusFilter
        let domain = selectedDomain
        let startedAtAfter = selectedTimeRange.cutOff()
        let pageSize = self.pageSize
        let store = self.store

        let page = await Task.detached(priority: .userInitiated) {
            store.loadListPage(
                limit: pageSize,
                status: status,
                domain: domain,
                startedAtAfter: startedAtAfter
            )
        }.value

        guard generation == reloadGeneration else { return }

        records = page.records
        nextPageCursor = page.nextCursor
        hasMoreRecords = page.hasMore
        if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = records.first?.id
            selectedDetail = nil
        }
        isLoading = false

        // These values are useful but not required to render the first page.
        // Run them after the list is on screen and discard stale results when a
        // filter changes while they are still running.
        Task { [store] in
            // The default view needs the total number of stored exchanges only.
            // Use SwiftData's count query directly instead of paging through all
            // records and rebuilding list snapshots. Filtered counts still need
            // the metadata scan because status/domain matching is performed in
            // Swift.
            let countTask = Task.detached(priority: .utility) {
                let isUnfiltered: Bool
                switch status {
                case .all:
                    isUnfiltered = domain == nil && startedAtAfter == nil
                case .normal, .abnormal:
                    isUnfiltered = false
                }

                if isUnfiltered {
                    return store.loadSnapshotCount()
                }
                return store.loadListCount(
                    status: status,
                    domain: domain,
                    startedAtAfter: startedAtAfter
                )
            }

            let seriesTask = Task.detached(priority: .utility) {
                store.loadDailyCountSeries()
            }
            let domainsTask = Task.detached(priority: .utility) {
                store.loadRecentDomains()
            }

            // Publish the total independently. It should not wait for the chart
            // or domain aggregation to finish.
            let loadedCount = await countTask.value
            guard generation == self.reloadGeneration else { return }
            self.totalRecordCount = loadedCount

            let loadedSeries = await seriesTask.value
            let loadedDomains = await domainsTask.value
            self.dailyCountSeries = loadedSeries
            self.domains = loadedDomains
        }
    }

    private func loadMoreAsync() async {
        guard !isLoading,
              !isLoadingMore,
              hasMoreRecords,
              let cursor = nextPageCursor else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let pageSize = self.pageSize
        let status = statusFilter
        let domain = selectedDomain
        let startedAtAfter = selectedTimeRange.cutOff()
        let store = self.store
        let page = await Task.detached(priority: .userInitiated) {
            store.loadListPage(
                limit: pageSize,
                beforeStartedAt: cursor,
                status: status,
                domain: domain,
                startedAtAfter: startedAtAfter
            )
        }.value

        records.append(contentsOf: page.records)
        nextPageCursor = page.nextCursor
        hasMoreRecords = page.hasMore
    }

    private var statusFilter: HTTPExchangeStatusFilter {
        switch selectedFilter {
        case .all: .all
        case .normal: .normal
        case .abnormal: .abnormal
        }
    }

    private func loadSelectedDetailAsync() async {
        guard let id = selectedRecordID else {
            selectedDetail = nil
            return
        }

        let store = self.store
        let detail = await Task.detached(priority: .userInitiated) {
            store.loadSnapshot(id: id)
        }.value

        guard selectedRecordID == id else { return }
        selectedDetail = detail
    }

    private var totalCountButton: some View {
        AppButton(totalCountDisplay, systemImage: "arrow.up.arrow.down.circle", size: .small) {
            isTotalCountPopoverPresented.toggle()
        }
        .accessibilityLabel(LumiPluginLocalization.string("Total HTTP exchanges", bundle: .module))
        .accessibilityValue(totalCountDisplay)
        .help(LumiPluginLocalization.string("Show total HTTP exchange details", bundle: .module))
        .popover(isPresented: $isTotalCountPopoverPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("Total HTTP exchanges", bundle: .module))
                    .font(.appBodyEmphasized)

                if let totalRecordCount {
                    Text(totalRecordCount.formatted(.number.grouping(.automatic)))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                }

                Text(LumiPluginLocalization.string("The number of HTTP exchange records currently stored locally. Each request and response round trip counts as one exchange; this is a record count, not network traffic volume.", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
        }
    }

    private var totalCountDisplay: String {
        totalRecordCount.map(String.init) ?? "—"
    }

    private func statusText(for record: HTTPExchangeExportSnapshot) -> String {
        if let statusCode = record.responseStatusCode { return String(statusCode) }
        return record.errorDescription == nil ? LumiPluginLocalization.string("Pending", bundle: .module) : LumiPluginLocalization.string("Error", bundle: .module)
    }

    private func statusText(for record: HTTPExchangeListSnapshot) -> String {
        if let statusCode = record.responseStatusCode { return String(statusCode) }
        return record.errorDescription == nil ? LumiPluginLocalization.string("Pending", bundle: .module) : LumiPluginLocalization.string("Error", bundle: .module)
    }

    private func statusColor(for record: HTTPExchangeExportSnapshot) -> Color {
        guard let statusCode = record.responseStatusCode else {
            return record.errorDescription == nil ? theme.textSecondary : .red
        }
        return (200..<300).contains(statusCode) ? .green : .orange
    }

    private func statusColor(for record: HTTPExchangeListSnapshot) -> Color {
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

    private func export(record: HTTPExchangeExportSnapshot) {
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

    /// Exports every record matching the current domain (and status) filter
    /// as one markdown file per record inside a user-chosen directory.
    /// Only shown while a domain is selected.
    ///
    /// Records are snapshotted on the main actor, then formatted and written
    /// on a background task so large batches don't block the UI; progress is
    /// reported to the status bar via `HTTPExportProgress`.
    private func exportFilteredLogs() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = LumiPluginLocalization.string("Choose Export Folder", bundle: .module)
        panel.prompt = LumiPluginLocalization.string("Export", bundle: .module)

        guard panel.runModal() == .OK, let directory = panel.url else { return }

        let status = statusFilter
        let domain = selectedDomain
        let startedAtAfter = selectedTimeRange.cutOff()
        let store = self.store

        // Export is an explicit user action, so it may load full bodies. The
        // normal list/detail path never does this for more than one record.
        Task { [store] in
            let snapshots = await Task.detached(priority: .userInitiated) {
                let summaries = store.loadAllListRecords(
                    status: status,
                    domain: domain,
                    startedAtAfter: startedAtAfter
                )
                return summaries.compactMap { store.loadSnapshot(id: $0.id) }
            }.value

            guard !snapshots.isEmpty else {
                self.exportErrorMessage = LumiPluginLocalization.string("No matching HTTP exchanges", bundle: .module)
                return
            }

            HTTPExportProgress.shared.begin(total: snapshots.count)
            Task.detached(priority: .userInitiated) {
                do {
                    for (index, snapshot) in snapshots.enumerated() {
                        let document = HTTPExchangeExportFormatter.document(for: snapshot)
                        let fileName = HTTPExchangeExportFormatter.exportFileName(for: snapshot, index: index)
                        try document.write(
                            to: directory.appendingPathComponent(fileName),
                            atomically: true,
                            encoding: .utf8
                        )
                        await MainActor.run { HTTPExportProgress.shared.advance() }
                    }
                    await MainActor.run { HTTPExportProgress.shared.finish() }
                } catch {
                    await MainActor.run { HTTPExportProgress.shared.fail(message: error.localizedDescription) }
                }
            }
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
