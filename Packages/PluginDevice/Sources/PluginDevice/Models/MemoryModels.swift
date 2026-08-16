import Foundation

public enum MemoryTimeRange: String, CaseIterable, Identifiable {
    case hour1
    case hour4
    case hour24
    case month1

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hour1: return LumiPluginLocalization.string("1h", bundle: .module)
        case .hour4: return LumiPluginLocalization.string("4h", bundle: .module)
        case .hour24: return LumiPluginLocalization.string("24h", bundle: .module)
        case .month1: return LumiPluginLocalization.string("30d", bundle: .module)
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

public struct MemoryDataPoint: Codable, Identifiable, Equatable, Sendable {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let usagePercentage: Double
    public let usedBytes: UInt64
}
