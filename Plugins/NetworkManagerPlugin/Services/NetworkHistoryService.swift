import Foundation
import Combine
import MagicKit
import OSLog

struct NetworkDataPoint: Identifiable, Codable {
    var id: TimeInterval { timestamp }
    let timestamp: TimeInterval
    let downloadSpeed: Double
    let uploadSpeed: Double
}

enum TimeRange: String, CaseIterable, Identifiable {
    case hour1 = "1小时"
    case hour4 = "4小时"
    case hour24 = "24小时"
    case month1 = "30天"
    
    var id: String { rawValue }
    
    var duration: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour4: return 14400
        case .hour24: return 86400
        case .month1: return 2592000
        }
    }
}

@MainActor
class NetworkHistoryService: ObservableObject, SuperLog {
    static let shared = NetworkHistoryService()
    static let emoji = "📊"
    static let verbose = true
    
    // Recent history (high resolution: 1 point per second for last hour)
    @Published var recentHistory: [NetworkDataPoint] = []
    
    // Long term history (low resolution: 1 point per minute for last 30 days)
    @Published var longTermHistory: [NetworkDataPoint] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var lastMinuteSampleTime: TimeInterval = 0
    private var minuteAccumulator: (down: Double, up: Double, count: Int) = (0, 0, 0)
    
    // Limits
    private let maxRecentPoints = 3600 // 1 hour at 1s interval
    private let maxLongTermPoints = 43200 // 30 days at 1m interval
    
    // Persistence
    private let storageURL: URL? = {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = url.appendingPathComponent("Lumi/NetworkManager")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()
    
    private init() {
        loadHistory()
        startRecording()
        
        // Auto save every 5 minutes
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.saveHistory()
            }
            .store(in: &cancellables)
    }
    
    func startRecording() {
        NetworkService.shared.startMonitoring()
        NetworkService.shared.$downloadSpeed
            .combineLatest(NetworkService.shared.$uploadSpeed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (down, up) in
                self?.recordDataPoint(down: down, up: up)
            }
            .store(in: &cancellables)
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
    
    func getData(for range: TimeRange) -> [NetworkDataPoint] {
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
            do {
                let data = try JSONEncoder().encode(history)
                try data.write(to: url)
            } catch {
                print("Failed to save network history: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadHistory() {
        guard let url = storageURL, let data = try? Data(contentsOf: url) else { return }
        if let loaded = try? JSONDecoder().decode([NetworkDataPoint].self, from: data) {
            // Filter out too old data
            let cutoff = Date().timeIntervalSince1970 - 2592000 // 30 days
            self.longTermHistory = loaded.filter { $0.timestamp >= cutoff }
        }
    }
}
