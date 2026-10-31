import Combine
import Foundation
import LumiLoggingKit
import os

/// CPU / die 温度历史采集服务。
///
/// 与 CPU / GPU / 内存历史服务保持一致的结构：高频缓冲(2s,保留 1 小时)+
/// 分钟级聚合缓冲(保留 30 天)。温度没有温度传感器可读时(Intel Mac),
/// 采样端不会写入任何数据,历史曲线自然为空。
@MainActor
public final class ThermalHistoryService: ObservableObject, SuperLog {
    public static let shared = ThermalHistoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.thermal-history")
    nonisolated public static let emoji = "🌡️"

    /// 高频缓冲(2s 采样)—— 保留最近 1 小时
    @Published public var recentHistory: [ThermalDataPoint] = []

    /// 分钟级聚合缓冲 —— 保留最近 30 天
    @Published public var longTermHistory: [ThermalDataPoint] = []

    private let maxRecentPoints = 1800 // 1 小时 / 2 秒
    private let maxLongTermPoints = 43200 // 30 天 * 24 小时 * 60 分钟

    private var minuteAccumulator: (sum: Double, count: Int) = (0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0

    private let storageFileName = "thermal_history.json"
    private let fileManager = FileManager.default

    /// 插件存储目录;由插件入口在 `onBoot` 注入。
    private static var pluginStorageDirectory: URL?

    /// 注入插件存储目录。应在 `onBoot` 中调用。
    ///
    /// 注入后立即补载历史:服务单例可能早于目录注入被创建,
    /// 那时目录为空、无法读到磁盘上的历史数据。
    public static func configure(storageDirectory: URL) {
        pluginStorageDirectory = storageDirectory
        shared.loadHistory()
    }

    private var storageFileURL: URL? {
        Self.pluginStorageDirectory?.appendingPathComponent(storageFileName)
    }

    package init() {}

    // MARK: - Public Methods

    public func startRecording() {
        // 输入采样由 DeviceMetricsObserver 负责。
    }

    public func stopRecording() {
        saveHistory()
    }

    /// 指定时间范围内的数据点。
    public func getData(for range: CPUTimeRange) -> [ThermalDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration

        switch range {
        case .hour1:
            return recentHistory.filter { $0.timestamp >= cutoff }
        default:
            var points = longTermHistory.filter { $0.timestamp >= cutoff }
            if minuteAccumulator.count > 0 {
                let avg = minuteAccumulator.sum / Double(minuteAccumulator.count)
                points.append(ThermalDataPoint(timestamp: now, celsius: avg))
            }
            return points
        }
    }

    // MARK: - Internal Methods

    /// 记录一个温度采样点。
    func recordDataPoint(celsius: Double) {
        let now = Date().timeIntervalSince1970
        let point = ThermalDataPoint(timestamp: now, celsius: celsius)

        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }

        let currentMinute = floor(now / 60) * 60
        if currentMinute > lastMinuteTimestamp {
            if lastMinuteTimestamp > 0, minuteAccumulator.count > 0 {
                let avg = minuteAccumulator.sum / Double(minuteAccumulator.count)
                longTermHistory.append(ThermalDataPoint(timestamp: lastMinuteTimestamp, celsius: avg))

                if longTermHistory.count > maxLongTermPoints {
                    longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
                }
                saveHistory()
            }
            lastMinuteTimestamp = currentMinute
            minuteAccumulator = (0, 0)
        }

        minuteAccumulator.sum += celsius
        minuteAccumulator.count += 1
    }

    // MARK: - Persistence

    @discardableResult
    func saveHistory() -> Task<Bool, Never>? {
        let historyToSave = longTermHistory
        guard let url = storageFileURL else { return nil }

        return Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try JSONEncoder().encode(historyToSave).write(to: url, options: .atomic)
                return true
            } catch {
                Self.logger.error("\(Self.t)Persist thermal history failed: \(error.localizedDescription)")
                return false
            }
        }
    }

    private func loadHistory() {
        guard let url = storageFileURL,
              fileManager.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let history = try JSONDecoder().decode([ThermalDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - CPUTimeRange.month1.duration
            longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {
            Self.logger.error("\(Self.t)Load thermal history failed: \(error.localizedDescription)")
        }
    }
}
