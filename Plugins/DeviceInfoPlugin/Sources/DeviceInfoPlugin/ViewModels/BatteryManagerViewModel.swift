import Combine
import Foundation
import SwiftUI

@MainActor
class BatteryManagerViewModel: ObservableObject {
    @ObservedObject var batteryService = BatteryService.shared

    // MARK: - Computed Properties

    /// Battery level percentage (0–100).
    var levelPercentage: Int {
        Int(batteryService.level * 100)
    }

    /// Battery level string (e.g. "85%").
    var levelString: String {
        "\(levelPercentage)%"
    }

    /// Health percentage string (e.g. "94%").
    var healthString: String {
        batteryService.hasBattery ? "\(Int(batteryService.healthPercentage))%" : "—"
    }

    /// Cycle count string.
    var cycleCountString: String {
        batteryService.hasBattery ? "\(batteryService.cycleCount)" : "—"
    }

    /// Temperature string (e.g. "35.2°C").
    var temperatureString: String {
        batteryService.temperatureString
    }

    /// Current power draw/charge string (e.g. "12.5 W").
    var wattsString: String {
        batteryService.wattsString
    }

    /// Adapter wattage string (e.g. "65.0 W").
    var adapterWattsString: String {
        batteryService.adapterWattsString
    }

    /// System power input string.
    var systemPowerInString: String {
        batteryService.systemPowerInString
    }

    /// Charge state description.
    var chargeStateDescription: String {
        batteryService.chargeStateDescription
    }

    /// Time remaining estimate (not available via IOKit directly, placeholder).
    var powerSourceLabel: String {
        switch batteryService.powerSource {
        case .battery: return "Battery"
        case .acPower: return "AC Power"
        case .ups: return "UPS"
        }
    }

    /// Whether to show battery details (hide for desktop Macs without battery).
    var showBatteryDetails: Bool {
        batteryService.hasBattery
    }

    // MARK: - Icon Helpers

    var batteryIcon: String {
        guard batteryService.hasBattery else { return "powerplug.fill" }
        let pct = levelPercentage
        if batteryService.isCharging {
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
        guard batteryService.hasBattery else { return .green }
        let pct = Double(levelPercentage)
        if pct > 50 { return .green }
        if pct > 20 { return .orange }
        return .red
    }

    var healthColor: Color {
        let h = batteryService.healthPercentage
        if h >= 80 { return .green }
        if h >= 60 { return .orange }
        return .red
    }

    var temperatureColor: Color {
        let t = batteryService.temperature
        if t < 35 { return .green }
        if t < 45 { return .orange }
        return .red
    }
}
