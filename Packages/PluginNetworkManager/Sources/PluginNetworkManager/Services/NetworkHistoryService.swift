import Foundation
import LumiLoggingKit
import Combine

public struct NetworkDataPoint: Identifiable, Codable, Sendable, SuperLog {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let downloadSpeed: Double
    public let uploadSpeed: Double
}

public enum TimeRange: String, CaseIterable, Identifiable {
    case hour1 = "1 Hour"
    case hour4 = "4 Hours"
    case hour24 = "24 Hours"
    case month1 = "30 Days"
    
    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .hour1: return "1h"
        case .hour4: return "4h"
        case .hour24: return "24h"
        case .month1: return "30d"
        }
    }
    
    public var duration: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour4: return 14400
        case .hour24: return 86400
        case .month1: return 2592000
        }
    }

    /// 仅 1 小时范围使用秒级高频缓冲,更长范围使用分钟级聚合缓冲。
    public var usesHighResolutionBuffer: Bool {
        self == .hour1
    }
}

@MainActor
public class NetworkHistoryService: ObservableObject, SuperLog {
    /// 不在静态初始化阶段创建旧版 Application Support 目录；插件启动时会注入
    /// 当前版本的插件 ID 目录。
    public static let shared = NetworkHistoryService(storageURL: nil, autoStartRecording: false)
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = false
    
    // Recent history (high resolution: 1 point per second for last hour)
    @Published var recentHistory: [NetworkDataPoint] = []
    
    // Long term history (low resolution: 1 point per minute for last 30 days)
    @Published var longTermHistory: [NetworkDataPoint] = []
    
    private var lastMinuteSampleTime: TimeInterval = 0
    private var minuteAccumulator: (down: Double, up: Double, count: Int) = (0, 0, 0)
    
    // Limits
    private let maxRecentPoints = 3600 // 1 hour at 1s interval
    private let maxLongTermPoints = 43200 // 30 days at 1m interval
    
    // Persistence
    private var storageURL: URL?

    /// 每次 configure 递增。在途后台加载写回前必须比对代次与目标 URL，
    /// 避免旧目录的加载结果覆盖刚切换后的新目录状态（AGENTS.md 身份校验）。
    private var loadGeneration = 0
    /// 在途的后台历史恢复任务；测试 seam 据此等待完成，避免轮询。
    private var restoreTask: Task<Void, Never>?

    init(storageURL: URL?, autoStartRecording: Bool) {
        self.storageURL = storageURL
        // 生产单例使用后台加载，避免启动时阻塞 UI；显式存储模式保持同步，
        // 让测试和需要立即读取持久化状态的调用方在初始化完成后即可观察结果。
        if autoStartRecording {
            let url = storageURL
            Task.detached(priority: .utility) { [weak self] in
                await self?.loadHistoryInBackground(url: url)
            }
        } else {
            loadHistory()
        }
        // NetworkMetricsObserver owns the source subscription and recording
        // lifecycle for the plugin.
    }

    /// 配置当前版本的插件数据目录。重新配置时清空内存快照，避免宿主重启
    /// 或测试切换目录后把两个目录的数据混在一起。
    ///
    /// 目录创建、读取、解码与过滤全部放到后台任务，configure 立即返回，
    /// 让 onBoot 的 UI / provider 注册不被 30 天历史（最多 43200 点）的
    /// 主 actor 解码阻塞（#1212）。恢复结果在后台准备好后回到主 actor 发布。
    func configure(storageDirectory: URL?) {
        storageURL = storageDirectory?.appendingPathComponent("history.json", isDirectory: false)
        recentHistory = []
        longTermHistory = []
        lastMinuteSampleTime = 0
        minuteAccumulator = (0, 0, 0)

        loadGeneration += 1
        let generation = loadGeneration
        let url = storageURL

        restoreTask?.cancel()
        restoreTask = Task.detached(priority: .utility) { [weak self] in
            guard let url else { return }
            Self.prepareStorageDirectory(for: url)
            let loaded = Self.readHistoryOffMain(url: url)
            await self?.publishLoadedHistory(loaded, url: url, generation: generation)
        }
    }

    /// 测试 seam：等待在途的后台历史恢复完成，避免轮询带来的不确定性。
    func waitForHistoryRestoreForTesting() async {
        await restoreTask?.value
    }

    /// 把后台准备好的历史发布到主 actor。写回前比对代次与目标 URL：
    /// 期间若已重新配置 / 切换目录，则丢弃这次在途结果，不覆盖新状态。
    @MainActor
    func publishLoadedHistory(_ loaded: [NetworkDataPoint]?, url: URL, generation: Int) {
        guard generation == loadGeneration, storageURL == url else { return }
        guard let loaded else { return }

        // 后台加载期间可能已录到新的分钟点；合并保留它们，避免旧加载覆盖新数据。
        var merged = loaded + longTermHistory
        if merged.count > maxLongTermPoints {
            merged.removeFirst(merged.count - maxLongTermPoints)
        }
        longTermHistory = merged
    }
    
    public func startRecording() {
        // Source observation is owned by NetworkMetricsObserver.
    }

    public func stopRecording() {
        saveHistory()
    }
    
    func recordDataPoint(down: Double, up: Double) {
        let now = Date().timeIntervalSince1970
        let point = NetworkDataPoint(timestamp: now, downloadSpeed: down, uploadSpeed: up)
        
        // Update recent history
        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }
        
        // Update long term history accumulator
        minuteAccumulator.down += down
        minuteAccumulator.up += up
        minuteAccumulator.count += 1
        
        // Check if minute passed (or if it's the first point)
        if lastMinuteSampleTime == 0 {
            lastMinuteSampleTime = now
        }
        
        if now - lastMinuteSampleTime >= 60 {
            if minuteAccumulator.count > 0 {
                let avgDown = minuteAccumulator.down / Double(minuteAccumulator.count)
                let avgUp = minuteAccumulator.up / Double(minuteAccumulator.count)
                
                let minutePoint = NetworkDataPoint(timestamp: lastMinuteSampleTime, downloadSpeed: avgDown, uploadSpeed: avgUp)
                longTermHistory.append(minutePoint)
                
                if longTermHistory.count > maxLongTermPoints {
                    longTermHistory.removeFirst(longTermHistory.count - maxLongTermPoints)
                }
            }
            
            // Reset accumulator
            minuteAccumulator = (0, 0, 0)
            lastMinuteSampleTime = now
            
            // Trigger save occasionally? handled by timer.
        }
    }
    
    public func getData(for range: TimeRange) -> [NetworkDataPoint] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - range.duration
        
        switch range {
        case .hour1:
            return recentHistory.filter { $0.timestamp >= cutoff }
        default:
            // For longer ranges, use long term history
            // But we might want to append the current accumulating minute to make it look "live"
            var points = longTermHistory.filter { $0.timestamp >= cutoff }
            
            // Add current accumulating minute as a point
            if minuteAccumulator.count > 0 {
                let avgDown = minuteAccumulator.down / Double(minuteAccumulator.count)
                let avgUp = minuteAccumulator.up / Double(minuteAccumulator.count)
                points.append(NetworkDataPoint(timestamp: now, downloadSpeed: avgDown, uploadSpeed: avgUp))
            }
            
            return points
        }
    }
    
    func saveHistory() {
        guard let url = storageURL else { return }
        Task.detached(priority: .background) { [history = self.longTermHistory] in
            Self.persistHistory(history, to: url)
        }
    }

    func saveHistorySynchronouslyForTesting() {
        guard let url = storageURL else { return }
        Self.persistHistory(longTermHistory, to: url)
    }
    
    private func loadHistory() {
        guard let url = storageURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([NetworkDataPoint].self, from: data)
            // Filter out too old data
            let cutoff = Date().timeIntervalSince1970 - 2592000 // 30 days
            self.longTermHistory = loaded.filter { $0.timestamp >= cutoff }
        } catch {
            if NetworkManagerPlugin.verbose {
                NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)Failed to load network history: \(error)")
            }
            Self.quarantineCorruptHistory(at: url)
        }
    }

    /// 后台加载历史数据（init 的 autoStartRecording 分支使用）。
    /// 复用 `readHistoryOffMain`，因此同样具备损坏文件隔离能力。
    @MainActor
    private func loadHistoryInBackground(url: URL?) async {
        guard let url else { return }
        let result = await Task.detached(priority: .utility) {
            Self.readHistoryOffMain(url: url)
        }.value
        if let result {
            longTermHistory = result
        }
    }

    /// 在后台线程创建存储目录。失败仅记录日志，不阻塞调用方。
    nonisolated private static func prepareStorageDirectory(for url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            NetworkManagerPlugin.logger.error(
                "\(NetworkHistoryService.t)Failed to configure network history directory: \(error.localizedDescription)"
            )
        }
    }

    /// 在后台线程读取 + 解码 + 按 30 天过滤历史；失败时隔离损坏文件并返回 nil。
    /// 不触碰任何主 actor 状态，可安全在 detached 任务中调用。
    nonisolated private static func readHistoryOffMain(url: URL) -> [NetworkDataPoint]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([NetworkDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - 2592000 // 30 days
            return loaded.filter { $0.timestamp >= cutoff }
        } catch {
            if NetworkManagerPlugin.verbose {
                NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)Failed to load network history: \(error)")
            }
            quarantineCorruptHistory(at: url)
            return nil
        }
    }

    nonisolated private static func persistHistory(_ history: [NetworkDataPoint], to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(history)
            try data.write(to: url, options: .atomic)
        } catch {
            if NetworkManagerPlugin.verbose {
                NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)Failed to save network history: \(error.localizedDescription)")
            }
        }
    }

    nonisolated private static func quarantineCorruptHistory(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let corruptURL = url.deletingLastPathComponent()
            .appendingPathComponent("history.corrupt.json", isDirectory: false)
        do {
            if FileManager.default.fileExists(atPath: corruptURL.path) {
                try FileManager.default.removeItem(at: corruptURL)
            }
            try FileManager.default.moveItem(at: url, to: corruptURL)
        } catch {
            if NetworkManagerPlugin.verbose {
                NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)Failed to quarantine corrupt network history: \(error.localizedDescription)")
            }
        }
    }
}
