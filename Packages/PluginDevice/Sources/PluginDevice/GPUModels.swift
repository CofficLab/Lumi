import Foundation

public enum GPUTimeRange: String, CaseIterable, Identifiable {
    case hour1
    case hour4
    case hour24
    case month1

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hour1: return LumiPluginLocalization.string("1 Hour", bundle: .module)
        case .hour4: return LumiPluginLocalization.string("4 Hours", bundle: .module)
        case .hour24: return LumiPluginLocalization.string("24 Hours", bundle: .module)
        case .month1: return LumiPluginLocalization.string("30 Days", bundle: .module)
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour4: return 14400
        case .hour24: return 86400
        case .month1: return 2592000
        }
    }
}

public struct GPUDataPoint: Codable, Identifiable, Equatable, Sendable {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let usage: Double
}

/// Single reading snapshot from IOKit GPU metrics.
public struct GPUReading: Sendable {
    /// GPU device utilization percentage (0–100).
    public let utilization: Double
    /// Renderer utilization percentage (0–100).
    public let rendererUtilization: Double
    /// Tiler utilization percentage (0–100).
    public let tilerUtilization: Double
    /// GPU memory currently in use (bytes).
    public let usedMemory: UInt64
    /// Total GPU memory allocated (bytes).
    public let totalMemory: UInt64
    /// GPU temperature in Celsius.
    public let temperature: Double
    /// GPU model name (e.g. "Apple M1 Pro GPU").
    public let modelName: String

    public static let empty = GPUReading(
        utilization: 0,
        rendererUtilization: 0,
        tilerUtilization: 0,
        usedMemory: 0,
        totalMemory: 0,
        temperature: 0,
        modelName: ""
    )
}
