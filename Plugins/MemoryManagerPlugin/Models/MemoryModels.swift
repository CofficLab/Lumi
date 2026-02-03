import Foundation

enum MemoryTimeRange: String, CaseIterable, Identifiable {
    case hour1 = "1小时"
    case hour4 = "4小时"
    case hour24 = "24小时"
    case month1 = "30天"

    var id: String { rawValue }

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
