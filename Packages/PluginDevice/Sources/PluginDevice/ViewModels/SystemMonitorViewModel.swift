import Foundation
import SwiftUI

@MainActor
class SystemMonitorViewModel: ObservableObject {
    @Published var metrics: SystemMetrics = .empty
    init() {
    }

    func apply(_ metrics: SystemMetrics) {
        self.metrics = metrics
    }
    
    func startMonitoring() {
        SystemMonitorService.shared.startMonitoring()
    }
    
    func stopMonitoring() {
        SystemMonitorService.shared.stopMonitoring()
    }
    
    // MARK: - Helpers
    
    var cpuColor: Color {
        MetricStatusScale.from(ratio: metrics.cpuUsage.percentage).themeColor
    }

    var memoryColor: Color {
        MetricStatusScale.from(ratio: metrics.memoryUsage.percentage).themeColor
    }
}
