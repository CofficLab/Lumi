import Foundation
import SwiftUI

@MainActor
class GPUManagerViewModel: ObservableObject {
    @Published private(set) var utilization: Double = 0
    @Published private(set) var rendererUtilization: Double = 0
    @Published private(set) var tilerUtilization: Double = 0
    @Published private(set) var usedMemoryString = "0 MB"
    @Published private(set) var totalMemoryString = "0 MB"
    @Published private(set) var memoryUsagePercent: Double = 0
    @Published private(set) var temperature: Double = 0
    @Published private(set) var rawModelName = ""

    func apply(_ service: GPUService) {
        utilization = service.utilization
        rendererUtilization = service.rendererUtilization
        tilerUtilization = service.tilerUtilization
        usedMemoryString = service.usedMemoryString
        totalMemoryString = service.totalMemoryString
        memoryUsagePercent = service.memoryUsagePercentage
        temperature = service.temperature
        rawModelName = service.modelName
    }

    // MARK: - Computed Properties

    /// GPU utilization percentage (0–100).
    /// Formatted utilization string (e.g. "37%").
    var utilizationString: String {
        "\(Int(utilization))%"
    }

    /// Renderer utilization string.
    var rendererUtilizationString: String {
        rendererUtilization > 0 ? "\(Int(rendererUtilization))%" : "--"
    }

    /// Tiler utilization string.
    var tilerUtilizationString: String {
        tilerUtilization > 0 ? "\(Int(tilerUtilization))%" : "--"
    }

    /// Formatted used GPU memory.
    var usedMemory: String {
        usedMemoryString
    }

    /// Formatted total GPU memory.
    var totalMemory: String {
        totalMemoryString
    }

    /// GPU memory usage percentage (0–100).
    var memoryUsagePercentage: Double {
        memoryUsagePercent
    }

    /// GPU temperature string (e.g. "45°C").
    var temperatureString: String {
        temperature > 0 ? String(format: "%.0f°C", temperature) : "--"
    }

    /// GPU model name.
    var modelName: String {
        rawModelName.isEmpty ? "GPU" : rawModelName
    }

    // MARK: - Color Helpers

    var utilizationColor: Color {
        MetricStatusScale.from(percentage: utilization).themeColor
    }

    var memoryColor: Color {
        MetricStatusScale.from(percentage: memoryUsagePercent).themeColor
    }
}
