import Combine
import Foundation
import LumiLoggingKit
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

    private var minuteAccumulator: (sumPct: Double, sumBytes: UInt64, count: Int) = (0, 0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "memory_history.json"
    private let fileManager = FileManager.default
    private let storageFileURLOverride: URL?

    /// Storage directory for this plugin. Configured via `configure()`.
    private static var pluginStorageDirectory: URL?

    /// Configure the storage directory. Should be called from `onBoot`.
    public static func configure(storageDirectory: URL) {
        pluginStorageDirectory = storageDirectory
    }

    /// Storage file URL. Configurable for testing.
    public var storageFileURL: URL? {
        if let storageFileURLOverride { return storageFileURLOverride }
        if let pluginDir = Self.pluginStorageDirectory {
            return pluginDir.appendingPathComponent(storageFileName)
        }
        return nil
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
        // Input observation is owned by DeviceMetricsObserver.
    }

    public func stopRecording() {
        // 先把当前这一分钟的聚合点结算进长期历史，再保存。
        // 否则会话末尾不足一分钟的采样在重启后永久丢失（#863）。
        settlePendingMinute()
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

    /// 把当前未完成分钟的聚合点结算进长期历史。
    ///
    /// 正常情况下这个点要等到下一分钟的采样到来才写入长期历史。若采样在此时
    /// 停止，图表上看得到的那个聚合点就不会落盘，重启后永久丢失（#863）。
    /// 停止时先结算一次，保证「已经显示出来的数据」不会因为没有跨分钟而消失。
    private func settlePendingMinute() {
        guard minuteAccumulator.count > 0 else { return }

        let avgPct = minuteAccumulator.sumPct / Double(minuteAccumulator.count)
        let avgBytes = minuteAccumulator.sumBytes / UInt64(minuteAccumulator.count)
        longTermHistory.append(
            MemoryDataPoint(
                timestamp: lastMinuteTimestamp,
                usagePercentage: avgPct,
                usedBytes: avgBytes
            )
        )

        if longTermHistory.count > maxLongTermPoints {
            longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
        }

        minuteAccumulator = (0, 0, 0)
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
