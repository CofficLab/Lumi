import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class CPUManagerViewModel: ObservableObject, SuperLog {
    static let emoji = "🧠"
    static let verbose = false
    
    @Published var cpuUsage: Double = 0.0
    @Published var loadAverage: [Double] = [0, 0, 0]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        startMonitoring()
    }

    deinit {
        Task { @MainActor in
            CPUService.shared.stopMonitoring()
        }
    }

    func startMonitoring() {
        CPUService.shared.startMonitoring()
        
        CPUService.shared.$cpuUsage
            .combineLatest(CPUService.shared.$loadAverage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (usage, load) in
                self?.cpuUsage = usage
                self?.loadAverage = load
            }
            .store(in: &cancellables)
    }
    
    var formattedLoadAverage: String {
        return loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  ")
    }
}
