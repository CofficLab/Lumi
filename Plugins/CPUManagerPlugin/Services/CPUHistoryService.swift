import Foundation
import Combine
import MagicKit
import OSLog

@MainActor
class CPUHistoryService: ObservableObject, SuperLog {
    static let shared = CPUHistoryService()
    static let emoji = "📈"
    
    // High resolution buffer (1s interval) - Keep last 1 hour
    @Published var recentHistory: [CPUDataPoint] = []
    
    // Low resolution buffer (1m interval) - Keep last 30 days
    @Published var longTermHistory: [CPUDataPoint] = []
    
    private let maxRecentPoints = 3600 // 1 hour * 60 seconds
    private let maxLongTermPoints = 43200 // 30 days * 24 hours * 60 minutes
    
    private var cancellables = Set<AnyCancellable>()
    private var minuteAccumulator: (sum: Double, count: Int) = (0, 0)
    private var lastMinuteTimestamp: TimeInterval = 0
    
    private let storageKey = "CPUHistoryData"
    
    private init() {
        loadHistory()
        startRecording()
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
        // Only save long term history to disk
        // Run on background thread
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
            let history = try JSONDecoder().decode([CPUDataPoint].self, from: data)
            // Filter out too old data
            let cutoff = Date().timeIntervalSince1970 - CPUTimeRange.month1.duration
            self.longTermHistory = history.filter { $0.timestamp >= cutoff }
        } catch {
            os_log(.error, "\(self.t)Failed to load history: \(error.localizedDescription)")
        }
    }
}
