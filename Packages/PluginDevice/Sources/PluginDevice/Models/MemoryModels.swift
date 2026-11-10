import Foundation

public enum MemoryTimeRange: String, CaseIterable, Identifiable, DeviceHistoryRange {
    case hour1
    case hour4
    case hour24
    case month1

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hour1: return pluginLocalization.string("1h")
        case .hour4: return pluginLocalization.string("4h")
        case .hour24: return pluginLocalization.string("24h")
        case .month1: return pluginLocalization.string("30d")
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

    /// 仅 1 小时范围使用秒级高频缓冲,更长范围使用分钟级聚合缓冲。
    public var usesHighResolutionBuffer: Bool {
        self == .hour1
    }
}

public struct MemoryDataPoint: Codable, Identifiable, Equatable, Sendable, DeviceHistorySample {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let usagePercentage: Double
    public let usedBytes: UInt64
}
