import Foundation

// MARK: - Memory Monitoring Models

enum MemoryTimeRange: String, CaseIterable, Identifiable {
    case hour1
    case hour4
    case hour24
    case month1

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hour1: return String(localized: "1h", table: "DeviceInfo")
        case .hour4: return String(localized: "4h", table: "DeviceInfo")
        case .hour24: return String(localized: "24h", table: "DeviceInfo")
        case .month1: return String(localized: "30d", table: "DeviceInfo")
        }
    }

    var duration: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour4: return 14400
        case .hour24: return 86400
        case .month1: return 2592000
        }
    }
}

struct MemoryDataPoint: Codable, Identifiable {
    var id: TimeInterval { timestamp }
    let timestamp: TimeInterval
    let usagePercentage: Double
    let usedBytes: UInt64
}
