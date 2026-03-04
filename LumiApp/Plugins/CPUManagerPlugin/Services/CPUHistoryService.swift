import Foundation
import Combine
import MagicKit
import OSLog

@MainActor
class CPUHistoryService: ObservableObject, SuperLog {
    static let shared = CPUHistoryService()
    nonisolated static let emoji = "📈"

    // High resolution buffer (1s interval) - Keep last 1 hour
    @Published var recentHistory: [CPUDataPoint] = []

    // Low resolution buffer (1m interval) - Keep last 30 days
    @Published var longTermHistory: [CPUDataPoint] = []

    private let maxRecentPoints = 3600 // 1 hour * 60 seconds
    private let maxLongTermPoints = 43200 // 30 days * 24 hours * 60 minutes

    private var cancellables = Set<AnyCancellable>()
    private var minuteAccumulator: (sum: Double, count: Int) = (0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "cpu_history.json"
    private let fileManager = FileManager.default

    private var storageFileURL: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.coffic.lumi/CPUHistory")
            .appendingPathComponent(storageFileName)
    }

    private init() {
        createStorageDirectoryIfNeeded()
        loadHistory()
        startRecording()
    }

    private func createStorageDirectoryIfNeeded() {
        guard let directory = storageFileURL?.deletingLastPathComponent() else { return }
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func startRecording() {
        CPUService.shared.startMonitoring()
        CPUService.shared.$cpuUsage
            .sink { [weak self] usage in
                self?.recordDataPoint(usage: usage)
            }
            .store(in: &cancellables)
    }

    private func recordDataPoint(usage: Double) {
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

    func getData(for range: CPUTimeRange) -> [CPUDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration

        switch range {
        case .hour1:
            return recentHistory.filter { $0.timestamp >= cutoff }
        default:
            var points = longTermHistory.filter { $0.timestamp >= cutoff }
            // Append current accumulating minute for real-time feel in long views
            if minuteAccumulator.count > 0 {
                let avgUsage = minuteAccumulator.sum / Double(minuteAccumulator.count)
                points.append(CPUDataPoint(timestamp: now, usage: avgUsage))
            }
            return points
        }
    }

    // MARK: - Persistence

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
            let history = try JSONDecoder().decode([CPUDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - CPUTimeRange.month1.duration
            self.longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {}
    }
}
