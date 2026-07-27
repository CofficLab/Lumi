import Foundation
import Combine
import SuperLogKit
import os

/// CPU history service with high-resolution (1s) and long-term (1m) storage.
@MainActor
public final class CPUHistoryService: ObservableObject, SuperLog {
    public static let shared = CPUHistoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.cpu-history")
    nonisolated public static let emoji = "📈"

    /// High resolution buffer (1s interval) - Keep last 1 hour
    @Published public var recentHistory: [CPUDataPoint] = []

    /// Low resolution buffer (1m interval) - Keep last 30 days
    @Published public var longTermHistory: [CPUDataPoint] = []

    private let maxRecentPoints = 3600 // 1 hour * 60 seconds
    private let maxLongTermPoints = 43200 // 30 days * 24 hours * 60 minutes

    private var cancellables = Set<AnyCancellable>()
    private var minuteAccumulator: (sum: Double, count: Int) = (0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "cpu_history.json"
    private let fileManager = FileManager.default
    private let storageFileURLOverride: URL?

    /// Storage file URL. Configurable for testing.
    public var storageFileURL: URL? {
        if let storageFileURLOverride { return storageFileURLOverride }
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.lumi/CPUHistory")
            .appendingPathComponent(storageFileName)
    }

    var corruptStorageFileURL: URL? {
        storageFileURL?.deletingLastPathComponent().appendingPathComponent("cpu_history.corrupt.json")
    }

    package init(storageFileURL: URL? = nil) {
        self.storageFileURLOverride = storageFileURL
        createStorageDirectoryIfNeeded()
        loadHistory()
    }

    // MARK: - Public Methods

    public func startRecording() {
        guard cancellables.isEmpty else { return }

        CPUService.shared.startMonitoring()
        CPUService.shared.$cpuUsage
            .sink { [weak self] usage in
                self?.recordDataPoint(usage: usage)
            }
            .store(in: &cancellables)
    }

    public func stopRecording() {
        guard !cancellables.isEmpty else { return }

        cancellables.removeAll()
        CPUService.shared.stopMonitoring()
        saveHistory()
    }

    public func getData(for range: CPUTimeRange) -> [CPUDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration

        switch range {
        case .hour1:
            return recentHistory.filter { $0.timestamp >= cutoff }
        default:
            var points = longTermHistory.filter { $0.timestamp >= cutoff }
            if minuteAccumulator.count > 0 {
                let avgUsage = minuteAccumulator.sum / Double(minuteAccumulator.count)
                points.append(CPUDataPoint(timestamp: now, usage: avgUsage))
            }
            return points
        }
    }

    // MARK: - Internal Methods

    func recordDataPoint(usage: Double) {
        let now = Date().timeIntervalSince1970
        let point = CPUDataPoint(timestamp: now, usage: usage)

        // Update Recent History
        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }

        // Update Long Term History (Aggregate to 1 minute)
        let currentMinute = floor(now / 60) * 60

        if currentMinute > lastMinuteTimestamp {
            // New minute started, save previous accumulated data
            if lastMinuteTimestamp > 0 && minuteAccumulator.count > 0 {
                let avgUsage = minuteAccumulator.sum / Double(minuteAccumulator.count)

                let longTermPoint = CPUDataPoint(timestamp: lastMinuteTimestamp, usage: avgUsage)
                longTermHistory.append(longTermPoint)

                if longTermHistory.count > maxLongTermPoints {
                    longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
                }

                saveHistory()
            }

            // Reset accumulator
            lastMinuteTimestamp = currentMinute
            minuteAccumulator = (0, 0)
        }

        minuteAccumulator.sum += usage
        minuteAccumulator.count += 1
    }

    // MARK: - Persistence

    @discardableResult
    func saveHistory() -> Task<Bool, Never>? {
        let historyToSave = longTermHistory
        let url = storageFileURL
        guard let url else { return nil }

        return Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try JSONEncoder().encode(historyToSave).write(to: url, options: .atomic)
                return true
            } catch {
                Self.logger.error("\(Self.t)Persist CPU history failed: \(error.localizedDescription)")
                return false
            }
        }
    }

    func loadHistory() {
        let url = storageFileURL
        guard let url,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let history = try JSONDecoder().decode([CPUDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - CPUTimeRange.month1.duration
            longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {
            Self.logger.error("\(Self.t)Load CPU history failed: \(error.localizedDescription)")
            quarantineCorruptHistory()
        }
    }

    // MARK: - Private Methods

    private func createStorageDirectoryIfNeeded() {
        guard let directory = storageFileURL?.deletingLastPathComponent() else { return }
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                Self.logger.error("\(Self.t)Create CPU history directory failed: \(error.localizedDescription)")
            }
        }
    }

    private func quarantineCorruptHistory() {
        guard let sourceURL = storageFileURL,
              let quarantineURL = corruptStorageFileURL,
              fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }

        do {
            if fileManager.fileExists(atPath: quarantineURL.path) {
                try fileManager.removeItem(at: quarantineURL)
            }
            try fileManager.moveItem(at: sourceURL, to: quarantineURL)
        } catch {
            Self.logger.error("\(Self.t)Quarantine corrupt CPU history failed: \(error.localizedDescription)")
        }
    }
}
