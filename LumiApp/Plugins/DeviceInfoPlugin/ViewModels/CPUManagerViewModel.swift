import Foundation
import Combine
import OSLog
import MagicKit

@MainActor
class CPUManagerViewModel: ObservableObject {
    static let emoji = "🧠"
    nonisolated static let verbose: Bool = false
    
    // MARK: - Properties
    
    @Published var cpuUsage: Double = 0.0
    @Published var perCoreUsage: [Double] = []
    @Published var loadAverage: [Double] = [0, 0, 0]
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        startMonitoring()
    }

    deinit {
        Task { @MainActor in
            CPUService.shared.stopMonitoring()
        }
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        CPUService.shared.startMonitoring()
        
        Publishers.CombineLatest3(
            CPUService.shared.$cpuUsage,
            CPUService.shared.$perCoreUsage,
            CPUService.shared.$loadAverage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] usage, perCoreUsage, load in
            self?.cpuUsage = usage
            self?.perCoreUsage = perCoreUsage
            self?.loadAverage = load
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var formattedLoadAverage: String {
        loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  ")
    }
}
