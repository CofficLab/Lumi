import Foundation
import Combine
import DeviceMonitorKit

@MainActor
class CPUManagerViewModel: ObservableObject {
    static let emoji = "🧠"
    nonisolated static let verbose: Bool = false
    
    // MARK: - Properties
    
    @Published var cpuUsage: Double = 0.0
    @Published var perCoreUsage: [Double] = []
    @Published var loadAverage: [Double] = [0, 0, 0]
    @Published var topProcesses: [ProcessMetric] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let monitorsProcesses: Bool
    
    // MARK: - Initialization
    
    init(monitorsProcesses: Bool = true) {
        self.monitorsProcesses = monitorsProcesses
        startMonitoring()
    }

    deinit {
        let monitorsProcesses = monitorsProcesses
        Task { @MainActor in
            CPUService.shared.stopMonitoring()
            if monitorsProcesses {
                ProcessService.shared.stopMonitoring()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        CPUService.shared.startMonitoring()
        if monitorsProcesses {
            ProcessService.shared.startMonitoring()
        }

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

        if monitorsProcesses {
            ProcessService.shared.$topProcesses
                .receive(on: DispatchQueue.main)
                .assign(to: &$topProcesses)
        }
    }
    
    // MARK: - Computed Properties
    
    var formattedLoadAverage: String {
        loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  ")
    }
}
