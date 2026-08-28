import Combine
import Foundation
import SwiftUI

@MainActor
class GPUManagerViewModel: ObservableObject {
    @ObservedObject var gpuService = GPUService.shared

    // MARK: - Computed Properties

    /// GPU utilization percentage (0–100).
    var utilization: Double {
        gpuService.utilization
    }

    /// Formatted utilization string (e.g. "37%").
    var utilizationString: String {
        "\(Int(gpuService.utilization))%"
    }

    /// Renderer utilization string.
    var rendererUtilizationString: String {
        gpuService.rendererUtilization > 0 ? "\(Int(gpuService.rendererUtilization))%" : "--"
    }

    /// Tiler utilization string.
    var tilerUtilizationString: String {
        gpuService.tilerUtilization > 0 ? "\(Int(gpuService.tilerUtilization))%" : "--"
    }

    /// Formatted used GPU memory.
    var usedMemory: String {
        gpuService.usedMemoryString
    }

    /// Formatted total GPU memory.
    var totalMemory: String {
        gpuService.totalMemoryString
    }

    /// GPU memory usage percentage (0–100).
    var memoryUsagePercentage: Double {
        gpuService.memoryUsagePercentage
    }

    /// GPU temperature string (e.g. "45°C").
    var temperatureString: String {
        gpuService.temperature > 0 ? String(format: "%.0f°C", gpuService.temperature) : "--"
    }

    /// GPU model name.
    var modelName: String {
        gpuService.modelName.isEmpty ? "GPU" : gpuService.modelName
    }

    // MARK: - Color Helpers

    var utilizationColor: Color {
        MetricStatusScale.from(percentage: gpuService.utilization).themeColor
    }

    var memoryColor: Color {
        MetricStatusScale.from(percentage: gpuService.memoryUsagePercentage).themeColor
    }
}
