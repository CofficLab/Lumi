import Foundation
import Combine
import MagicKit
import OSLog

@MainActor
class MemoryHistoryService: ObservableObject, SuperLog {
    static let shared = MemoryHistoryService()
    nonisolated static let emoji = "📈"
    
    // High resolution buffer (1s interval) - Keep last 1 hour
    @Published var recentHistory: [MemoryDataPoint] = []
    
    // Low resolution buffer (1m interval) - Keep last 30 days
    @Published var longTermHistory: [MemoryDataPoint] = []
    
    private let maxRecentPoints = 3600
    private let maxLongTermPoints = 43200
    
    private var cancellables = Set<AnyCancellable>()
    private var minuteAccumulator: (sumPct: Double, sumBytes: UInt64, count: Int) = (0, 0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0
    
    private let storageKey = "MemoryHistoryData"
    
    private init() {
        loadHistory()
        startRecording()
    }
    
    func startRecording() {
        MemoryService.shared.startMonitoring()
        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory)
            .sink { [weak self] (pct, bytes) in
                self?.recordDataPoint(pct: pct, bytes: bytes)
            }
            .store(in: &cancellables)
    }
    
    private func recordDataPoint(pct: Double, bytes: UInt64) {
        let now = Date().timeIntervalSince1970
        let point = MemoryDataPoint(timestamp: now, usagePercentage: pct, usedBytes: bytes)
        
        // Update Recent History
        recentHistory.append(point)
        if recentHistory.count > maxRecentPoints {
            recentHistory.removeFirst(recentHistory.count - maxRecentPoints)
        }
        
        // Update Long Term History
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
    
    private func saveHistory() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(self.longTermHistory)
                UserDefaults.standard.set(data, forKey: self.storageKey)
            } catch {
                os_log(.error, "\(self.t)Failed to save history: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let history = try JSONDecoder().decode([MemoryDataPoint].self, from: data)
            let cutoff = Date().timeIntervalSince1970 - MemoryTimeRange.month1.duration
            self.longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {
            os_log(.error, "\(self.t)Failed to load history: \(error.localizedDescription)")
        }
    }
}
