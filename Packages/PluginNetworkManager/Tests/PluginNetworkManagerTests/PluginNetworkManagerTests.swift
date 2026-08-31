import Testing
import Combine
import Foundation
import SQLite3
@testable import PluginNetworkManager

@MainActor
@Test func publicIPRefreshUsesCache() async throws {
    let fetcher = PublicIPFetcherStub(values: ["203.0.113.10"])
    let viewModel = NetworkManagerViewModel(autoStartMonitoring: false) {
        await fetcher.fetch()
    }

    await viewModel.refreshPublicIPIfNeeded()
    await viewModel.refreshPublicIPIfNeeded()

    #expect(await fetcher.count == 1)
    #expect(viewModel.networkState.publicIP == "203.0.113.10")
}

@MainActor
@Test func publicIPRefreshCanBeForced() async throws {
    let fetcher = PublicIPFetcherStub(values: ["203.0.113.1", "203.0.113.2"])
    let viewModel = NetworkManagerViewModel(autoStartMonitoring: false) {
        await fetcher.fetch()
    }

    await viewModel.refreshPublicIPIfNeeded()
    await viewModel.refreshPublicIPIfNeeded(force: true)

    #expect(await fetcher.count == 2)
    #expect(viewModel.networkState.publicIP == "203.0.113.2")
}

@MainActor
@Test func processMonitorToggleIgnoresRepeatedAssignments() {
    let counter = ProcessMonitorCounter()
    let viewModel = NetworkManagerViewModel(
        autoStartMonitoring: false,
        processMonitoringStarter: { counter.starts += 1 },
        processMonitoringStopper: { counter.stops += 1 }
    )

    viewModel.showProcessMonitor = true
    viewModel.showProcessMonitor = true
    viewModel.showProcessMonitor = false
    viewModel.showProcessMonitor = false

    #expect(counter.starts == 1)
    #expect(counter.stops == 1)
}

@MainActor
@Test func networkUsageUpdatePublishesOnce() {
    let viewModel = NetworkManagerViewModel(autoStartMonitoring: false)
    var publishCount = 0
    var cancellables = Set<AnyCancellable>()

    viewModel.objectWillChange
        .sink { publishCount += 1 }
        .store(in: &cancellables)

    viewModel.applyNetworkUsage(
        downloadSpeed: 120,
        uploadSpeed: 34,
        totalDownload: 1_000,
        totalUpload: 500
    )

    #expect(publishCount == 1)
    #expect(viewModel.networkState.downloadSpeed == 120)
    #expect(viewModel.networkState.uploadSpeed == 34)
    #expect(viewModel.networkState.totalDownload == 1_000)
    #expect(viewModel.networkState.totalUpload == 500)
}

@MainActor
@Test func networkHistoryQuarantinesInvalidStorageAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("NetworkHistoryService-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let historyURL = directory.appendingPathComponent("history.json")
    let corruptURL = directory.appendingPathComponent("history.corrupt.json")
    let invalidData = Data("not json".utf8)
    try invalidData.write(to: historyURL)

    let service = NetworkHistoryService(storageURL: historyURL, autoStartRecording: false)

    #expect(service.longTermHistory.isEmpty)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)

    let point = NetworkDataPoint(timestamp: Date().timeIntervalSince1970, downloadSpeed: 120, uploadSpeed: 34)
    service.longTermHistory = [point]
    service.saveHistorySynchronouslyForTesting()

    let reloadedService = NetworkHistoryService(storageURL: historyURL, autoStartRecording: false)
    #expect(reloadedService.longTermHistory.count == 1)
    #expect(reloadedService.longTermHistory.first?.timestamp == point.timestamp)
    #expect(reloadedService.longTermHistory.first?.downloadSpeed == point.downloadSpeed)
    #expect(reloadedService.longTermHistory.first?.uploadSpeed == point.uploadSpeed)
}

@Test func dailyHTTPExchangeCountSeriesIncludesEmptyDaysAndIgnoresOlderRecords() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29, hour: 12))!
    let records = [
        HTTPExchangeRecord(startedAt: calendar.date(byAdding: .day, value: -1, to: now)!, requestMethod: "GET", requestURL: "https://example.com/1", requestHeadersJSON: Data("{}".utf8), requestBody: nil, requestDetailsJSON: Data("{}".utf8)),
        HTTPExchangeRecord(startedAt: calendar.date(byAdding: .day, value: -1, to: now)!, requestMethod: "POST", requestURL: "https://example.com/2", requestHeadersJSON: Data("{}".utf8), requestBody: nil, requestDetailsJSON: Data("{}".utf8)),
        HTTPExchangeRecord(startedAt: calendar.date(byAdding: .day, value: -14, to: now)!, requestMethod: "GET", requestURL: "https://example.com/old", requestHeadersJSON: Data("{}".utf8), requestBody: nil, requestDetailsJSON: Data("{}".utf8)),
    ]

    let series = HTTPExchangeDailyCountSeries.build(records: records, calendar: calendar, days: 14, endingAt: now)

    #expect(series.points.count == 14)
    #expect(series.totalCount == 2)
    #expect(series.peakCount == 2)
    #expect(series.points.dropLast().contains { $0.count == 0 })
    #expect(series.points.last?.count == 0)
}

@Test func httpExchangeExportIncludesRequestResponseAndErrorDetails() {
    let record = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 0),
        requestMethod: "POST",
        requestURL: "https://example.com/api",
        requestHeadersJSON: Data("{\"Authorization\":\"Bearer test\"}".utf8),
        requestBody: Data("{\"prompt\":\"hello\"}".utf8),
        requestDetailsJSON: Data("{\"timeout\":30}".utf8)
    )
    record.responseStatusCode = 201
    record.responseHeadersJSON = Data("{\"content-type\":\"application/json\"}".utf8)
    record.responseBody = Data("{\"ok\":true}".utf8)
    record.duration = 1.25
    record.errorDescription = "server warning"
    record.errorDomain = "Test"
    record.errorCode = 7
    record.errorDetailsJSON = Data("{\"retryable\":true}".utf8)

    let document = HTTPExchangeExportFormatter.document(for: record)

    #expect(document.contains("POST"))
    #expect(document.contains("https://example.com/api"))
    #expect(document.contains("\"prompt\""))
    #expect(document.contains("hello"))
    #expect(document.contains("201"))
    #expect(document.contains("\"ok\""))
    #expect(document.contains("true"))
    #expect(document.contains("server warning"))
    #expect(document.contains("Test"))
    #expect(document.contains("retryable"))
}

@MainActor
@Test func fetchDomainsCollectsDistinctHostsFromRecentRecords() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPExchangeStore-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
    store.begin(request: URLRequest(url: URL(string: "https://api.github.com/users/octocat")!))
    store.begin(request: URLRequest(url: URL(string: "https://api.github.com/gists")!))
    store.begin(request: URLRequest(url: URL(string: "https://www.google.com/search?q=lumi")!))
    // Hostless URL (file scheme) must be skipped, not crash the aggregation.
    store.begin(request: URLRequest(url: URL(string: "file:///tmp/lumi")!))

    let domains = store.fetchDomains()
    #expect(domains == ["api.github.com", "www.google.com"])
}

@MainActor
@Test func httpExchangeRetentionKeepsOnlyRecentRecordsWithinCountLimit() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPExchangeRetention-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = HTTPExchangeStore(directory: directory)
    let now = Date()
    store.begin(
        request: URLRequest(url: URL(string: "https://example.com/expired")!),
        startedAt: now.addingTimeInterval(-31 * 24 * 60 * 60)
    )
    store.begin(
        request: URLRequest(url: URL(string: "https://example.com/oldest-recent")!),
        startedAt: now.addingTimeInterval(-3 * 24 * 60 * 60)
    )
    store.begin(
        request: URLRequest(url: URL(string: "https://example.com/newer")!),
        startedAt: now.addingTimeInterval(-2 * 24 * 60 * 60)
    )
    store.begin(
        request: URLRequest(url: URL(string: "https://example.com/newest")!),
        startedAt: now
    )

    _ = await store.cleanupRetentionNow(
        now: now,
        retentionDays: 30,
        maxRecordCount: 2
    )

    let reloadedStore = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
    let remaining = reloadedStore.fetchPage(limit: 10)
    #expect(remaining.count == 2)
    #expect(remaining.map(\.requestURL) == [
        "https://example.com/newest",
        "https://example.com/newer",
    ])
}

@MainActor
@Test func searchPageAndCountFilterByExactHost() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPExchangeStore-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = HTTPExchangeStore(directory: directory)
    store.begin(request: URLRequest(url: URL(string: "https://api.github.com/users")!))
    store.begin(request: URLRequest(url: URL(string: "https://github.com/octocat")!))
    store.begin(request: URLRequest(url: URL(string: "https://www.google.com/")!))

    let page = store.searchPage(limit: 100, domain: "api.github.com")
    #expect(page.count == 1)
    #expect(page.first?.requestURL == "https://api.github.com/users")

    // Exact-host matching: api.github.com must NOT match the github.com filter.
    #expect(store.searchCount(domain: "github.com") == 1)
    #expect(store.searchCount(domain: "api.github.com") == 1)
    #expect(store.searchCount(domain: "google.com") == 0)
}

@MainActor
@Test func listPageFiltersMetadataAndLoadsBodiesOnlyForSelectedDetail() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPExchangeList-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
    let now = Date()
    let body = Data(repeating: 0x41, count: 128 * 1024)
    let response = HTTPURLResponse(
        url: URL(string: "https://example.com/api")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!

    var recordIDs: [UUID] = []
    for offset in 0..<6 {
        var request = URLRequest(url: URL(string: "https://example.com/api/\(offset)")!)
        request.httpMethod = "POST"
        request.httpBody = body
        let record = store.begin(
            request: request,
            startedAt: now.addingTimeInterval(TimeInterval(offset))
        )!
        store.finish(record, response: response, body: body)
        recordIDs.append(record.id)
    }

    let page = store.loadListPage(limit: 2, status: .normal)
    #expect(page.records.count == 2)
    #expect(page.records.allSatisfy { $0.responseStatusCode == 200 })
    #expect(page.records.allSatisfy { $0.url.contains("example.com/api") })

    let detail = store.loadSnapshot(id: page.records[0].id)
    #expect(detail?.requestBody?.count == body.count)
    #expect(detail?.responseBody?.count == body.count)

    let allSummaries = store.loadAllListRecords(status: .normal)
    #expect(allSummaries.count == recordIDs.count)
    #expect(allSummaries.allSatisfy { $0.responseStatusCode == 200 })
}

@MainActor
@Test func httpExchangeStoreCreatesStartedAtIndexForExistingStoreCompatibility() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HTTPExchangeIndex-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
    let databaseURL = store.directory.appendingPathComponent(HTTPExchangeStore.databaseFileName)
    var database: OpaquePointer?
    let openResult = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    #expect(openResult == SQLITE_OK)
    guard openResult == SQLITE_OK, let database else { return }
    defer { sqlite3_close(database) }

    var statement: OpaquePointer?
    let sql = "SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = 'ZHTTPExchangeRecordStartedAtIndex' LIMIT 1"
    let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
    #expect(prepareResult == SQLITE_OK)
    guard prepareResult == SQLITE_OK, let statement else { return }
    defer { sqlite3_finalize(statement) }
    #expect(sqlite3_step(statement) == SQLITE_ROW)
}

@Test func httpExchangeBatchExportIncludesAllRecordsWithNumberedHeaders() {
    let record1 = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 1),
        requestMethod: "GET",
        requestURL: "https://api.github.com/users",
        requestHeadersJSON: Data("{}".utf8),
        requestBody: nil,
        requestDetailsJSON: Data("{}".utf8)
    )
    record1.responseStatusCode = 200
    let record2 = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 2),
        requestMethod: "POST",
        requestURL: "https://api.github.com/gists",
        requestHeadersJSON: Data("{}".utf8),
        requestBody: nil,
        requestDetailsJSON: Data("{}".utf8)
    )
    record2.responseStatusCode = 201

    let document = HTTPExchangeExportFormatter.document(for: [record1, record2], filterTitle: "api.github.com")

    #expect(document.contains("# HTTP Exchange Logs"))
    #expect(document.contains("- Filter: `api.github.com`"))
    #expect(document.contains("- Total: 2"))
    #expect(document.contains("# 1. GET https://api.github.com/users"))
    #expect(document.contains("# 2. POST https://api.github.com/gists"))
    // Per-record sections survive inside the batch document.
    #expect(document.contains("## Summary"))
    #expect(document.contains("200"))
    #expect(document.contains("201"))
}

@Test func httpExchangeSnapshotExportMatchesRecordExport() {
    let record = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 0),
        requestMethod: "POST",
        requestURL: "https://example.com/api",
        requestHeadersJSON: Data("{\"Authorization\":\"Bearer test\"}".utf8),
        requestBody: Data("{\"prompt\":\"hello\"}".utf8),
        requestDetailsJSON: Data("{\"timeout\":30}".utf8)
    )
    record.responseStatusCode = 201
    record.responseHeadersJSON = Data("{\"content-type\":\"application/json\"}".utf8)
    record.responseBody = Data("{\"ok\":true}".utf8)
    record.duration = 1.25
    record.errorDescription = "server warning"
    record.errorDomain = "Test"
    record.errorCode = 7
    record.errorDetailsJSON = Data("{\"retryable\":true}".utf8)

    let snapshot = HTTPExchangeExportSnapshot(record: record)
    #expect(HTTPExchangeExportFormatter.document(for: snapshot) == HTTPExchangeExportFormatter.document(for: record))
}

@Test func batchExportFromSnapshotsReportsProgressPerRecord() {
    let record1 = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 1),
        requestMethod: "GET",
        requestURL: "https://api.github.com/users",
        requestHeadersJSON: Data("{}".utf8),
        requestBody: nil,
        requestDetailsJSON: Data("{}".utf8)
    )
    let record2 = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 2),
        requestMethod: "POST",
        requestURL: "https://api.github.com/gists",
        requestHeadersJSON: Data("{}".utf8),
        requestBody: nil,
        requestDetailsJSON: Data("{}".utf8)
    )
    let snapshots = [HTTPExchangeExportSnapshot(record: record1), HTTPExchangeExportSnapshot(record: record2)]

    var progressCount = 0
    let document = HTTPExchangeExportFormatter.document(for: snapshots, filterTitle: "api.github.com") {
        progressCount += 1
    }

    #expect(progressCount == 2)
    #expect(document.contains("- Total: 2"))
    #expect(document.contains("# 1. GET https://api.github.com/users"))
    #expect(document.contains("# 2. POST https://api.github.com/gists"))
}

@Test func exportFileNameIsStableUniqueAndSanitized() {
    let record = HTTPExchangeRecord(
        startedAt: Date(timeIntervalSince1970: 1),
        requestMethod: "GET",
        requestURL: "https://api.github.com/users/octocat",
        requestHeadersJSON: Data("{}".utf8),
        requestBody: nil,
        requestDetailsJSON: Data("{}".utf8)
    )
    let snapshot = HTTPExchangeExportSnapshot(record: record)

    let name0 = HTTPExchangeExportFormatter.exportFileName(for: snapshot, index: 0)
    let name1 = HTTPExchangeExportFormatter.exportFileName(for: snapshot, index: 1)

    #expect(name0 == "00001-GET-api.github.com-users-octocat.md")
    #expect(name1 == "00002-GET-api.github.com-users-octocat.md")
    #expect(name0 != name1)
}

@Test func timeRangeFilterCutOffsAreCorrect() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    #expect(HTTPExchangeSettingsView.TimeRangeFilter.all.cutOff(relativeTo: now) == nil)
    #expect(HTTPExchangeSettingsView.TimeRangeFilter.lastHour.cutOff(relativeTo: now) == now.addingTimeInterval(-3600))
    #expect(HTTPExchangeSettingsView.TimeRangeFilter.lastTenMinutes.cutOff(relativeTo: now) == now.addingTimeInterval(-600))
    #expect(HTTPExchangeSettingsView.TimeRangeFilter.today.cutOff(relativeTo: now) == Calendar.current.startOfDay(for: now))
}

@MainActor
@Test func exportProgressTracksLifecycleAndFailure() {
    let progress = HTTPExportProgress.shared

    progress.begin(total: 3)
    #expect(progress.isExporting)
    #expect(progress.completed == 0)
    progress.advance()
    progress.advance()
    #expect(progress.completed == 2)
    #expect(progress.statusText.contains("2/3"))
    progress.finish()
    #expect(!progress.isExporting)
    #expect(progress.completed == 3)
    #expect(progress.errorMessage == nil)

    progress.begin(total: 5)
    progress.fail(message: "disk full")
    #expect(!progress.isExporting)
    #expect(progress.errorMessage == "disk full")
    progress.clearError()
    #expect(progress.errorMessage == nil)
}

@Test func emitSSEEventsSplitsByBlankLineAndKeepsTail() async {
    let provider = NetworkProvider()

    // 多个 `data: {...}` 事件 + 一个 [DONE]，事件间以空行分隔。
    let event1 = "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\",\"content\":\"\"}}]}"
    let event2 = "data: {\"choices\":[{\"delta\":{\"content\":\"# 项目介绍\"}}]}"
    let event3 = "data: {\"choices\":[{\"delta\":{\"content\":\"\\n\\n正文\"}}]}"
    let event4 = "data: [DONE]"
    let body = [event1, event2, event3, event4].joined(separator: "\n\n") + "\n\n"

    final class Collector: @unchecked Sendable { var events: [String] = [] }
    let collector = Collector()

    let shouldContinue = await provider.emitSSEEvents(from: Data(body.utf8)) { data in
        collector.events.append(String(data: data, encoding: .utf8) ?? "")
        return true
    }

    #expect(shouldContinue)
    // 空行的 `\n\n` 会匹配双换行，但首个事件前无内容；应切出 4 个事件。
    #expect(collector.events.count == 4, "应切出 4 个完整事件块，实际 \(collector.events.count)")
    #expect(collector.events[0].hasPrefix("data: "))
    #expect(collector.events[1].contains("项目介绍"))
    #expect(collector.events[2].contains("正文"))
    #expect(collector.events[3] == "data: [DONE]")
}

@Test func emitSSEEventsHonorsStopAndHandlesDelimiterVariants() async {
    let provider = NetworkProvider()

    // 混用 CRLF 结尾事件 + CRCR 边界；并验证返回 false 可提前终止。
    let crlfEvent = "data: {\"a\":1}\r\n\r\n"
    final class Counter: @unchecked Sendable { var count = 0 }
    let counter = Counter()
    let stopped = await provider.emitSSEEvents(from: Data(crlfEvent.utf8)) { _ in
        counter.count += 1
        return false
    }
    #expect(counter.count == 1)
    #expect(!stopped)

    // CRCR 作为空行分隔符也应被识别。
    let crcrEvent = "data: {\"b\":2}\r\rdata: [DONE]\r\r"
    final class CrCollector: @unchecked Sendable { var events: [String] = [] }
    let crCollector = CrCollector()
    _ = await provider.emitSSEEvents(from: Data(crcrEvent.utf8)) { data in
        crCollector.events.append(String(data: data, encoding: .utf8) ?? "")
        return true
    }
    #expect(crCollector.events.count == 2)
    #expect(crCollector.events[0] == "data: {\"b\":2}")
    #expect(crCollector.events[1] == "data: [DONE]")
}

private actor PublicIPFetcherStub {
    private(set) var count = 0
    private let values: [String]

    init(values: [String]) {
        self.values = values
    }

    func fetch() -> String? {
        count += 1
        return values[min(count - 1, values.count - 1)]
    }
}

@MainActor
private final class ProcessMonitorCounter {
    var starts = 0
    var stops = 0
}
