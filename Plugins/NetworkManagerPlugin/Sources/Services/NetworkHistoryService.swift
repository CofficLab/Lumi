import Foundation
import SuperLogKit
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
}

@MainActor
public class NetworkHistoryService: ObservableObject, SuperLog {
    public static let shared = NetworkHistoryService()
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = false
    
    // Recent history (high resolution: 1 point per second for last hour)
    @Published var recentHistory: [NetworkDataPoint] = []
    
    // Long term history (low resolution: 1 point per minute for last 30 days)
    @Published var longTermHistory: [NetworkDataPoint] = []
    
    private var recordingCancellables = Set<AnyCancellable>()
    private var autosaveCancellable: AnyCancellable?
    private var isRecording = false
    private var lastMinuteSampleTime: TimeInterval = 0
    private var minuteAccumulator: (down: Double, up: Double, count: Int) = (0, 0, 0)
    
    // Limits
    private let maxRecentPoints = 3600 // 1 hour at 1s interval
    private let maxLongTermPoints = 43200 // 30 days at 1m interval
    
    // Persistence
    private let storageURL: URL?

    private static func defaultStorageURL() -> URL? {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = url.appendingPathComponent("Lumi/NetworkManager")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            if NetworkManagerPlugin.verbose {
                NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)Failed to create network history directory: \(error.localizedDescription)")
            }
            return nil
        }
        return dir.appendingPathComponent("history.json")
    }

    private convenience init() {
        self.init(storageURL: Self.defaultStorageURL(), autoStartRecording: true)
    }

    init(storageURL: URL?, autoStartRecording: Bool) {
        self.storageURL = storageURL
        loadHistory()
        if autoStartRecording {
            startRecording()
        }
    }
    
    public func startRecording() {
        guard !isRecording else { return }
        isRecording = true

        NetworkService.shared.startMonitoring()
        NetworkService.shared.$downloadSpeed
            .combineLatest(NetworkService.shared.$uploadSpeed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (down, up) in
                self?.recordDataPoint(down: down, up: up)
            }
            .store(in: &recordingCancellables)

        startAutosave()
    }

    public func stopRecording() {
        guard isRecording else { return }

        saveHistory()
        isRecording = false
        recordingCancellables.removeAll()
        autosaveCancellable?.cancel()
        autosaveCancellable = nil
        NetworkService.shared.stopMonitoring()
    }

    private func startAutosave() {
        guard autosaveCancellable == nil else { return }

        autosaveCancellable = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.saveHistory()
            }
    }
    
    private func recordDataPoint(down: Double, up: Double) {
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
    
    private func saveHistory() {
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
                NetworkManagerPlugin.logger.error("\(NetworkHistoryService.t)Failed to load network history: \(error.localizedDescription)")
            }
            quarantineCorruptHistory(at: url)
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

    private func quarantineCorruptHistory(at url: URL) {
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
