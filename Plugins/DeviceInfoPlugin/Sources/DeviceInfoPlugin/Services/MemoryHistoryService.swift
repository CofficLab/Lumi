import Combine
import Foundation
import SuperLogKit
import os

/// Memory history service with high-resolution (1s) and long-term (1m) storage.
@MainActor
public final class MemoryHistoryService: ObservableObject, SuperLog {
    public static let shared = MemoryHistoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.memory-history")
    nonisolated public static let emoji = "📉"

    @Published public var recentHistory: [MemoryDataPoint] = []
    @Published public var longTermHistory: [MemoryDataPoint] = []

    private let maxRecentPoints = 3600
    private let maxLongTermPoints = 43200

    private var cancellables = Set<AnyCancellable>()
    private var minuteAccumulator: (sumPct: Double, sumBytes: UInt64, count: Int) = (0, 0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "memory_history.json"
    private let fileManager = FileManager.default
    private let storageFileURLOverride: URL?

    /// Storage file URL. Configurable for testing.
    public var storageFileURL: URL? {
        if let storageFileURLOverride { return storageFileURLOverride }
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.lumi/MemoryHistory")
            .appendingPathComponent(storageFileName)
    }

    var corruptStorageFileURL: URL? {
        storageFileURL?.deletingLastPathComponent().appendingPathComponent("memory_history.corrupt.json")
    }

    package init(storageFileURL: URL? = nil) {
        self.storageFileURLOverride = storageFileURL
        createStorageDirectoryIfNeeded()
        loadHistory()
    }

    // MARK: - Public Methods

    public func startRecording() {
        guard cancellables.isEmpty else { return }

        MemoryService.shared.startMonitoring()
        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory)
            .sink { [weak self] pct, bytes in
                self?.recordDataPoint(pct: pct, bytes: bytes)
            }
            .store(in: &cancellables)
    }

    public func stopRecording() {
        guard !cancellables.isEmpty else { return }

        cancellables.removeAll()
        MemoryService.shared.stopMonitoring()
        saveHistory()
    }

    public func getData(for range: MemoryTimeRange) -> [MemoryDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration

        switch range {
        case .hour1:
            return recentHistory.filter { $0.timestamp >= cutoff }
        default:
            var points = longTermHistory.filter { $0.timestamp >= cutoff }
            if minuteAccumulator.count > 0 {
                let avgPct = minuteAccumulator.sumPct / Double(minuteAccumulator.count)
                let avgBytes = minuteAccumulator.sumBytes / UInt64(minuteAccumulator.count)
                points.append(MemoryDataPoint(timestamp: now, usagePercentage: avgPct, usedBytes: avgBytes))
            }
            return points
        }
    }

    // MARK: - Internal Methods

    func recordDataPoint(pct: Double, bytes: UInt64) {
        let now = Date().timeIntervalSince1970
        let point = MemoryDataPoint(timestamp: now, usagePercentage: pct, usedBytes: bytes)

        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }

        let currentMinute = floor(now / 60) * 60

        if currentMinute > lastMinuteTimestamp {
            if lastMinuteTimestamp > 0 && minuteAccumulator.count > 0 {
                let avgPct = minuteAccumulator.sumPct / Double(minuteAccumulator.count)
                let avgBytes = minuteAccumulator.sumBytes / UInt64(minuteAccumulator.count)

                let longTermPoint = MemoryDataPoint(timestamp: lastMinuteTimestamp, usagePercentage: avgPct, usedBytes: avgBytes)
                longTermHistory.append(longTermPoint)

                if longTermHistory.count > maxLongTermPoints {
                    longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
                }

                saveHistory()
            }

            lastMinuteTimestamp = currentMinute
            minuteAccumulator = (0, 0, 0)
        }

        minuteAccumulator.sumPct += pct
        minuteAccumulator.sumBytes += bytes
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
                Self.logger.error("\(Self.t)Persist memory history failed: \(error.localizedDescription)")
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
            let history = try JSONDecoder().decode([MemoryDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - MemoryTimeRange.month1.duration
            longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {
            Self.logger.error("\(Self.t)Load memory history failed: \(error.localizedDescription)")
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
                Self.logger.error("\(Self.t)Create memory history directory failed: \(error.localizedDescription)")
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
            Self.logger.error("\(Self.t)Quarantine corrupt memory history failed: \(error.localizedDescription)")
        }
    }
}
