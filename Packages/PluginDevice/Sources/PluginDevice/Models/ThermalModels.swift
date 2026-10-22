import Foundation

/// CPU / die 温度的历史采样点。
public struct ThermalDataPoint: Codable, Identifiable, Equatable, Sendable {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let celsius: Double
}
