import Combine
import Foundation
import os
import LumiLoggingKit
/// GPU history service with high-resolution (2s) and long-term (1m) storage.
@MainActor
public final class GPUHistoryService: ObservableObject, SuperLog {
    public static let shared = GPUHistoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.gpu-history")
    nonisolated public static let emoji = "📊"

    /// High resolution buffer (2s interval) — keep last 1 hour
    @Published public var recentHistory: [GPUDataPoint] = []

    /// Low resolution buffer (1m interval) — keep last 30 days
    @Published public var longTermHistory: [GPUDataPoint] = []

    private let maxRecentPoints = 1800 // 1 hour / 2 seconds
    private let maxLongTermPoints = 43200 // 30 days * 24 hours * 60 minutes

    private var minuteAccumulator: (sum: Double, count: Int) = (0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "gpu_history.json"
    private let fileManager = FileManager.default
    private let storageFileURLOverride: URL?

    public var storageFileURL: URL? {
        if let storageFileURLOverride { return storageFileURLOverride }
        let bundleIdentifier = Bundle.main.bundleIdentifier
            ?? "com.coffic.lumi"
        return fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("GPUHistory", isDirectory: true)
            .appendingPathComponent(storageFileName)
    }

    var corruptStorageFileURL: URL? {
        storageFileURL?.deletingLastPathComponent().appendingPathComponent("gpu_history.corrupt.json")
    }

    package init(storageFileURL: URL? = nil) {
        self.storageFileURLOverride = storageFileURL
        createStorageDirectoryIfNeeded()
        loadHistory()
    }

    // MARK: - Public Methods

    public func startRecording() {
        // Input observation is owned by DeviceMetricsObserver.
    }

    public func stopRecording() {
        // 先把当前这一分钟的聚合点结算进长期历史，再保存。
        // 否则会话末尾不足一分钟的采样在重启后永久丢失（#863）。
        settlePendingMinute()
        saveHistory()
    }

    public func getData(for range: GPUTimeRange) -> [GPUDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration

        switch range {
        case .hour1:
            return recentHistory.filter { $0.timestamp >= cutoff }
        default:
            var points = longTermHistory.filter { $0.timestamp >= cutoff }
            if minuteAccumulator.count > 0 {
                let avgUsage = minuteAccumulator.sum / Double(minuteAccumulator.count)
                points.append(GPUDataPoint(timestamp: now, usage: avgUsage))
            }
            return points
        }
    }

    // MARK: - Internal Methods

    func recordDataPoint(usage: Double) {
        let now = Date().timeIntervalSince1970
        let point = GPUDataPoint(timestamp: now, usage: usage)

        // Update Recent History
        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }

        // Update Long Term History (Aggregate to 1 minute)
        let currentMinute = floor(now / 60) * 60

        if currentMinute > lastMinuteTimestamp {
            if lastMinuteTimestamp > 0, minuteAccumulator.count > 0 {
                let avgUsage = minuteAccumulator.sum / Double(minuteAccumulator.count)
                let longTermPoint = GPUDataPoint(timestamp: lastMinuteTimestamp, usage: avgUsage)
                longTermHistory.append(longTermPoint)

                if longTermHistory.count > maxLongTermPoints {
                    longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
                }

                saveHistory()
            }

            lastMinuteTimestamp = currentMinute
            minuteAccumulator = (0, 0)
        }

        minuteAccumulator.sum += usage
        minuteAccumulator.count += 1
    }

    // MARK: - Persistence

    /// 把当前未完成分钟的聚合点结算进长期历史。
    ///
    /// 正常情况下这个点要等到下一分钟的采样到来才写入长期历史。若采样在此时
    /// 停止，图表上看得到的那个聚合点就不会落盘，重启后永久丢失（#863）。
    /// 停止时先结算一次，保证「已经显示出来的数据」不会因为没有跨分钟而消失。
    private func settlePendingMinute() {
        guard minuteAccumulator.count > 0 else { return }

        let avgUsage = minuteAccumulator.sum / Double(minuteAccumulator.count)
        longTermHistory.append(GPUDataPoint(timestamp: lastMinuteTimestamp, usage: avgUsage))

        if longTermHistory.count > maxLongTermPoints {
            longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
        }

        minuteAccumulator = (0, 0)
    }

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
                Self.logger.error("\(Self.t)Persist GPU history failed: \(error.localizedDescription)")
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
            let history = try JSONDecoder().decode([GPUDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - GPUTimeRange.month1.duration
            longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {
            Self.logger.error("\(Self.t)Load GPU history failed: \(error.localizedDescription)")
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
                Self.logger.error("\(Self.t)Create GPU history directory failed: \(error.localizedDescription)")
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
            Self.logger.error("\(Self.t)Quarantine corrupt GPU history failed: \(error.localizedDescription)")
        }
    }
}
