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
