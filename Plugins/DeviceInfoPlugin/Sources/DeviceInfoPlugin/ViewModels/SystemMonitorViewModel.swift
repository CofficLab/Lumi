import Foundation
import Combine
import SwiftUI

@MainActor
class SystemMonitorViewModel: ObservableObject {
    @Published var metrics: SystemMetrics = .empty
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoring = false
    
    init() {
        SystemMonitorService.shared.$currentMetrics
            .receive(on: RunLoop.main)
            .sink { [weak self] metrics in
                self?.metrics = metrics
            }
            .store(in: &cancellables)
    }

    deinit {
        Task { @MainActor in
            SystemMonitorService.shared.stopMonitoring()
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        SystemMonitorService.shared.startMonitoring()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        SystemMonitorService.shared.stopMonitoring()
    }
    
    // MARK: - Helpers
    
    var cpuColor: Color {
        metricColor(value: metrics.cpuUsage.percentage)
    }
    
    var memoryColor: Color {
        metricColor(value: metrics.memoryUsage.percentage)
    }
    
    private func metricColor(value: Double) -> Color {
        if value < 0.6 { return .green }
        if value < 0.85 { return .orange }
        return .red
    }
}
