import Foundation

/// Power source state.
public enum BatteryPowerSource: String, Sendable {
    case battery = "Battery Power"
    case acPower = "AC Power"
    case ups = "UPS Power"
}

/// Detailed charging state.
public enum BatteryChargeState: String, Sendable {
    case notCharging
    case charging
    case charged
    /// Desktop Mac without internal battery, running on AC power.
    case acOnly
}

/// Single reading snapshot from IOKit AppleSmartBattery metrics.
public struct BatteryReading: Sendable {
    /// Battery level as fraction (0.0–1.0).
    public let level: Double
    /// Is the battery currently charging.
    public let isCharging: Bool
    /// Is the battery fully charged.
    public let isCharged: Bool
    /// Is the AC adapter connected.
    public let isACConnected: Bool
    /// Battery cycle count.
    public let cycleCount: Int
    /// Design capacity (mAh).
    public let designCapacity: Int
    /// Max capacity (mAh) — current full-charge capacity.
    public let maxCapacity: Int
    /// Battery health percentage (0–100): MaxCapacity / DesignCapacity × 100.
    public let healthPercentage: Double
    /// Battery temperature in Celsius.
    public let temperature: Double
    /// Battery voltage (mV).
    public let voltage: Int
    /// Battery amperage (mA). Negative = charging, positive = discharging.
    public let amperage: Int
    /// Current power draw/charge in Watts.
    public let watts: Double
    /// AC adapter wattage (W). 0 if unknown or not connected.
    public let adapterWatts: Double
    /// System total power input in Watts (from PowerTelemetryData).
    public let systemPowerIn: Double
    /// Battery power in Watts (from PowerTelemetryData). Negative = charging.
    public let batteryPower: Double
    /// Power source type.
    public let powerSource: BatteryPowerSource
    /// Detailed charge state.
    public let chargeState: BatteryChargeState
    /// Whether this device has an internal battery.
    public let hasBattery: Bool

    public static let empty = BatteryReading(
        level: 0,
        isCharging: false,
        isCharged: false,
        isACConnected: false,
        cycleCount: 0,
        designCapacity: 0,
        maxCapacity: 0,
        healthPercentage: 0,
        temperature: 0,
        voltage: 0,
        amperage: 0,
        watts: 0,
        adapterWatts: 0,
        systemPowerIn: 0,
        batteryPower: 0,
        powerSource: .acPower,
        chargeState: .acOnly,
        hasBattery: false
    )
}

/// Battery data point for history trend charts.
public struct BatteryDataPoint: Codable, Identifiable, Equatable, Sendable {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    /// Power in Watts at this point.
    public let watts: Double
}

public enum BatteryTimeRange: String, CaseIterable, Identifiable {
    case minute1
    case minute5
    case minute30
    case hour1

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .minute1: return LumiPluginLocalization.string("1 Min", bundle: .module)
        case .minute5: return LumiPluginLocalization.string("5 Min", bundle: .module)
        case .minute30: return LumiPluginLocalization.string("30 Min", bundle: .module)
        case .hour1: return LumiPluginLocalization.string("1 Hour", bundle: .module)
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .minute1: return 60
        case .minute5: return 300
        case .minute30: return 1800
        case .hour1: return 3600
        }
    }
}
