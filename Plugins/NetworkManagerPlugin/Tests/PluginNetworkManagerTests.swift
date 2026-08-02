import Testing
import Combine
import Foundation
@testable import NetworkManagerPlugin

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
