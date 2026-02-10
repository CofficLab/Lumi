import Foundation

enum CPUTimeRange: String, CaseIterable, Identifiable {
    case hour1 = "1 Hour"
    case hour4 = "4 Hours"
    case hour24 = "24 Hours"
    case month1 = "30 Days"

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

struct CPUDataPoint: Codable, Identifiable {
    var id: TimeInterval { timestamp }
    let timestamp: TimeInterval
    let usage: Double
}
