import Foundation
import SwiftUI

@MainActor
class BatteryManagerViewModel: ObservableObject {
    @Published private(set) var level: Double = 0
    @Published private(set) var healthPercentage: Double = 0
    @Published private(set) var cycleCount: Int = 0
    @Published private(set) var temperature: Double = 0
    @Published private(set) var watts: Double = 0
    @Published private(set) var adapterWatts: Double = 0
    @Published private(set) var hasBattery = false
    @Published private(set) var isCharging = false
    @Published private(set) var powerSource: BatteryPowerSource = .acPower
    @Published private(set) var adapterWattsText = "0 W"
    @Published private(set) var systemPowerInText = "0 W"
    @Published private(set) var chargeStateText = "AC Power"

    func apply(_ service: BatteryService) {
        level = service.level
        healthPercentage = service.healthPercentage
        cycleCount = service.cycleCount
        temperature = service.temperature
        watts = service.watts
        adapterWatts = service.adapterWatts
        hasBattery = service.hasBattery
        isCharging = service.isCharging
        powerSource = service.powerSource
        adapterWattsText = service.adapterWattsString
        systemPowerInText = service.systemPowerInString
        chargeStateText = service.chargeStateDescription
    }

    // MARK: - Computed Properties

    /// Battery level percentage (0–100).
    var levelPercentage: Int {
        Int(level * 100)
    }

    /// Battery level string (e.g. "85%").
    var levelString: String {
        "\(levelPercentage)%"
    }

    /// Health percentage string (e.g. "94%").
    var healthString: String {
        hasBattery ? "\(Int(healthPercentage))%" : "—"
    }

    /// Cycle count string.
    var cycleCountString: String {
        hasBattery ? "\(cycleCount)" : "—"
    }

    /// Temperature string (e.g. "35.2°C").
    var temperatureString: String {
        temperature > 0 ? String(format: "%.1f°C", temperature) : "--"
    }

    /// Current power draw/charge string (e.g. "12.5 W").
    var wattsString: String {
        String(format: "%.1f W", watts)
    }

    /// Adapter wattage string (e.g. "65.0 W").
    var adapterWattsString: String {
        adapterWattsText
    }

    /// System power input string.
    var systemPowerInString: String {
        systemPowerInText
    }

    /// Charge state description.
    var chargeStateDescription: String {
        chargeStateText
    }

    /// Time remaining estimate (not available via IOKit directly, placeholder).
    var powerSourceLabel: String {
        switch powerSource {
        case .battery: return "Battery"
        case .acPower: return "AC Power"
        case .ups: return "UPS"
        }
    }

    /// Whether to show battery details (hide for desktop Macs without battery).
    var showBatteryDetails: Bool {
        hasBattery
    }

    // MARK: - Icon Helpers

    var batteryIcon: String {
        guard hasBattery else { return "powerplug.fill" }
        let pct = levelPercentage
        if isCharging {
            return "battery.100.bolt"
        }
        if pct >= 90 { return "battery.100" }
        if pct >= 65 { return "battery.75" }
        if pct >= 40 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    // MARK: - Color Helpers

    var levelColor: Color {
        guard hasBattery else { return MetricStatus.normal.themeColor }
        return MetricStatus.batteryLevel(level).themeColor
    }

    var healthColor: Color {
        MetricStatus.batteryHealth(healthPercentage).themeColor
    }

    var temperatureColor: Color {
        MetricStatus.temperature(temperature).themeColor
    }
}
