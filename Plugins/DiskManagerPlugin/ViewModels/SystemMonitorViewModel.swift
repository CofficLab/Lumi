import Foundation
import Combine
import SwiftUI

@MainActor
class SystemMonitorViewModel: ObservableObject {
    @Published var metrics: SystemMetrics = .empty
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        SystemMonitorService.shared.$currentMetrics
            .receive(on: RunLoop.main)
            .assign(to: \.metrics, on: self)
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        SystemMonitorService.shared.startMonitoring()
    }
    
    func stopMonitoring() {
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
