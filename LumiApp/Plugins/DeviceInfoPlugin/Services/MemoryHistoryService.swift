import Combine
import Foundation
import MagicKit

@MainActor
class MemoryHistoryService: ObservableObject, SuperLog {
    nonisolated static let verbose: Bool = false
    static let shared = MemoryHistoryService()
    nonisolated static let emoji = "📈"

    @Published var recentHistory: [MemoryDataPoint] = []
    @Published var longTermHistory: [MemoryDataPoint] = []

    private let maxRecentPoints = 3600
    private let maxLongTermPoints = 43200

    private var cancellables = Set<AnyCancellable>()
    private var minuteAccumulator: (sumPct: Double, sumBytes: UInt64, count: Int) = (0, 0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "memory_history.json"
    private let fileManager = FileManager.default

    private var storageFileURL: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.lumi/MemoryHistory")
            .appendingPathComponent(storageFileName)
    }

    private init() {
        createStorageDirectoryIfNeeded()
        loadHistory()
        startRecording()
    }

    // MARK: - Public Methods

    func startRecording() {
        MemoryService.shared.startMonitoring()
        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory)
            .sink { [weak self] pct, bytes in
                self?.recordDataPoint(pct: pct, bytes: bytes)
            }
            .store(in: &cancellables)
    }

    func getData(for range: MemoryTimeRange) -> [MemoryDataPoint] {
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

    // MARK: - Private Methods

    private func createStorageDirectoryIfNeeded() {
        guard let directory = storageFileURL?.deletingLastPathComponent() else { return }
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func recordDataPoint(pct: Double, bytes: UInt64) {
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

    private func saveHistory() {
        let historyToSave = longTermHistory
        guard let url = storageFileURL else { return }

        Task.detached(priority: .background) {
            try? JSONEncoder().encode(historyToSave).write(to: url, options: .atomic)
        }
    }

    private func loadHistory() {
        guard let url = storageFileURL,
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return
        }

        do {
            let history = try JSONDecoder().decode([MemoryDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - MemoryTimeRange.month1.duration
            self.longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {}
    }
}
