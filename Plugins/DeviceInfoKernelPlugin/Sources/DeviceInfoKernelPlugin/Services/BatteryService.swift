import Combine
import Foundation
import IOKit
import IOKit.ps
import os
import SuperLogKit

/// Enhanced battery monitoring service.
///
/// Reads battery data from two sources:
/// 1. **AppleSmartBattery** IOKit service — cycle count, design/max capacity, temperature, voltage, amperage.
/// 2. **IOPowerSources** API — battery level, charging state, power source.
/// 3. **PowerTelemetryData** (IOKit registry) — system power input, battery power.
/// 4. **IOPSCopyExternalPowerAdapterDetails** — AC adapter wattage.
@MainActor
public final class BatteryService: ObservableObject, SuperLog {
    public static let shared = BatteryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.battery")
    nonisolated public static let emoji = "🔋"
    nonisolated(unsafe) static var verbose: Bool = false

    // MARK: - Published Properties

    /// Battery level as fraction (0.0–1.0).
    @Published public var level: Double = 0
    /// Is the battery currently charging.
    @Published public var isCharging: Bool = false
    /// Is fully charged.
    @Published public var isCharged: Bool = false
    /// Is AC adapter connected.
    @Published public var isACConnected: Bool = false
    /// Battery cycle count.
    @Published public var cycleCount: Int = 0
    /// Battery health percentage (0–100).
    @Published public var healthPercentage: Double = 0
    /// Design capacity (mAh).
    @Published public var designCapacity: Int = 0
    /// Max (full-charge) capacity (mAh).
    @Published public var maxCapacity: Int = 0
    /// Battery temperature in Celsius.
    @Published public var temperature: Double = 0
    /// Battery voltage (mV).
    @Published public var voltage: Int = 0
    /// Battery amperage (mA).
    @Published public var amperage: Int = 0
    /// Current power draw/charge in Watts.
    @Published public var watts: Double = 0
    /// AC adapter wattage (W).
    @Published public var adapterWatts: Double = 0
    /// System total power input in Watts.
    @Published public var systemPowerIn: Double = 0
    /// Battery power in Watts (negative = charging).
    @Published public var batteryPower: Double = 0
    /// Power source type.
    @Published public var powerSource: BatteryPowerSource = .acPower
    /// Detailed charge state.
    @Published public var chargeState: BatteryChargeState = .acOnly
    /// Whether this device has an internal battery.
    @Published public var hasBattery: Bool = true

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    private var subscribersCount = 0

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 开始电池增强监控")
            }
            sampleBattery()

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.sampleBattery()
                }
            }
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 停止电池增强监控")
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            samplingTask?.cancel()
            samplingTask = nil
        }
    }

    // MARK: - Convenience

    /// Formatted watt string (e.g. "15.2 W").
    public var wattsString: String {
        Self.wattString(watts)
    }

    /// Formatted adapter watt string (e.g. "65.0 W").
    public var adapterWattsString: String {
        adapterWatts > 0 ? Self.wattString(adapterWatts) : "—"
    }

    /// Formatted system power input string.
    public var systemPowerInString: String {
        systemPowerIn > 0 ? Self.wattString(systemPowerIn) : "—"
    }

    /// Formatted temperature string (e.g. "35.2°C").
    public var temperatureString: String {
        temperature > 0 ? String(format: "%.1f°C", temperature) : "—"
    }

    /// Health status label.
    public var healthLabel: String {
        if healthPercentage >= 80 { return "Good" }
        if healthPercentage >= 60 { return "Fair" }
        return "Poor"
    }

    /// Charge state description for display.
    public var chargeStateDescription: String {
        switch chargeState {
        case .notCharging: return hasBattery ? "Not Charging" : "AC Power"
        case .charging: return "Charging"
        case .charged: return "Fully Charged"
        case .acOnly: return "AC Power"
        }
    }

    // MARK: - Sampling

    private func sampleBattery() {
        guard samplingTask == nil else { return }

        samplingTask = Task.detached(priority: .utility) {
            let reading = Self.readBattery()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.subscribersCount > 0 else { return }

                self.level = reading.level
                self.isCharging = reading.isCharging
                self.isCharged = reading.isCharged
                self.isACConnected = reading.isACConnected
                self.cycleCount = reading.cycleCount
                self.designCapacity = reading.designCapacity
                self.maxCapacity = reading.maxCapacity
                self.healthPercentage = reading.healthPercentage
                self.temperature = reading.temperature
                self.voltage = reading.voltage
                self.amperage = reading.amperage
                self.watts = reading.watts
                self.adapterWatts = reading.adapterWatts
                self.systemPowerIn = reading.systemPowerIn
                self.batteryPower = reading.batteryPower
                self.powerSource = reading.powerSource
                self.chargeState = reading.chargeState
                self.hasBattery = reading.hasBattery
            }
        }
    }

    // MARK: - IOKit Reading (nonisolated)

    private nonisolated static func readBattery() -> BatteryReading {
        // 1. Read from AppleSmartBattery IOKit service
        let smcData = readSmartBattery()
        let hasBattery = smcData.hasBattery

        // 2. Read from IOPowerSources API
        let (iopsLevel, iopsCharging, iopsCharged, iopsACConnected, iopsSource) = readIOPS()

        // 3. Read AC adapter details
        let adapterW = readAdapterWatts()

        // 4. Read PowerTelemetryData
        let (sysPowerIn, battPower) = readPowerTelemetry()

        // Determine charge state
        let chargeState: BatteryChargeState
        if !hasBattery {
            chargeState = .acOnly
        } else if iopsCharged {
            chargeState = .charged
        } else if iopsCharging {
            chargeState = .charging
        } else {
            chargeState = .notCharging
        }

        return BatteryReading(
            level: hasBattery ? iopsLevel : 0,
            isCharging: iopsCharging,
            isCharged: iopsCharged,
            isACConnected: iopsACConnected,
            cycleCount: smcData.cycleCount,
            designCapacity: smcData.designCapacity,
            maxCapacity: smcData.maxCapacity,
            healthPercentage: smcData.healthPercentage,
            temperature: smcData.temperature,
            voltage: smcData.voltage,
            amperage: smcData.amperage,
            watts: smcData.watts,
            adapterWatts: adapterW,
            systemPowerIn: sysPowerIn,
            batteryPower: battPower,
            powerSource: iopsSource,
            chargeState: chargeState,
            hasBattery: hasBattery
        )
    }

    // MARK: - AppleSmartBattery IOKit

    private struct SMCBatteryData {
        var hasBattery: Bool = false
        var cycleCount: Int = 0
        var designCapacity: Int = 0
        var maxCapacity: Int = 0
        var healthPercentage: Double = 0
        var temperature: Double = 0
        var voltage: Int = 0
        var amperage: Int = 0
        var watts: Double = 0
    }

    private nonisolated static func readSmartBattery() -> SMCBatteryData {
        var data = SMCBatteryData()

        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else {
            data.hasBattery = false
            return data
        }
        defer { IOObjectRelease(service) }

        // Determine whether this Mac has an internal battery.
        //
        // The registry keys are inconsistent across models:
        // - `BatteryPresent` / `BuiltIn` exist on many Intel Macs but are ABSENT
        //   on recent Apple Silicon Macs (returning -1 below), which previously
        //   caused laptops to be misdetected as battery-less desktops and always
        //   rendered as "AC Power".
        // - `BatteryInstalled` (1 = battery fitted) is the reliable cross-model key.
        //
        // A real desktop without an internal battery has none of these keys, so we
        // treat "no battery keys at all" (all three absent) as the desktop case.
        let batteryPresent = intFromRegistry(service, "BatteryPresent")
        let builtIn = intFromRegistry(service, "BuiltIn")
        let batteryInstalled = intFromRegistry(service, "BatteryInstalled")

        if !Self.hasInternalBattery(batteryPresent: batteryPresent, builtIn: builtIn, batteryInstalled: batteryInstalled) {
            data.hasBattery = false
            return data
        }

        data.hasBattery = true
        data.cycleCount = max(0, intFromRegistry(service, "CycleCount"))
        data.designCapacity = max(0, intFromRegistry(service, "DesignCapacity"))
        data.maxCapacity = max(0, intFromRegistry(service, "MaxCapacity"))

        if data.designCapacity > 0 {
            data.healthPercentage = Double(data.maxCapacity) / Double(data.designCapacity) * 100.0
        }

        data.temperature = doubleFromRegistry(service, "Temperature") / 100.0
        data.voltage = max(0, intFromRegistry(service, "Voltage"))
        data.amperage = intFromRegistry(service, "Amperage")

        // Power calculation: P = V × I / 1000
        // Voltage is in mV, Amperage is in mA → Watts = mV × mA / 1,000,000
        let voltageF = Double(data.voltage)
        let amperageF = Double(data.amperage)
        data.watts = abs(voltageF * amperageF / 1_000_000.0)

        return data
    }

    // MARK: - IOPowerSources API

    private nonisolated static func readIOPS() -> (
        level: Double,
        isCharging: Bool,
        isCharged: Bool,
        isACConnected: Bool,
        source: BatteryPowerSource
    ) {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []

        var level: Double = 0
        var isCharging = false
        var isCharged = false
        var isACConnected = false
        var source: BatteryPowerSource = .battery

        // Find the internal battery power source first
        var batterySource: [String: Any]?
        var upsSource: [String: Any]?

        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let type = desc[kIOPSTypeKey] as? String ?? ""
            if type == kIOPSInternalBatteryType {
                batterySource = desc
                break  // Found the battery, stop searching
            } else if type == "UPS" {
                upsSource = desc
            }
        }

        // Use battery source if found, otherwise try UPS
        let desc = batterySource ?? upsSource ?? [:]

        if !desc.isEmpty {
            if let current = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                level = Double(current) / Double(max)
            }
            isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            isCharged = desc[kIOPSIsChargedKey] as? Bool ?? false
            isACConnected = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

            let type = desc[kIOPSTypeKey] as? String ?? ""
            switch type {
            case kIOPSInternalBatteryType:
                source = isACConnected ? .acPower : .battery
            case "UPS":
                source = .ups
            default:
                source = .battery
            }
        }

        return (level, isCharging, isCharged, isACConnected, source)
    }

    // MARK: - AC Adapter

    private nonisolated static func readAdapterWatts() -> Double {
        guard let adapterInfo = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] else {
            return 0
        }
        // Adapter details may contain "Watts" key
        if let watts = adapterInfo[kIOPSPowerAdapterWattsKey] as? Int {
            return Double(watts)
        }
        return 0
    }

    // MARK: - Power Telemetry

    private nonisolated static func readPowerTelemetry() -> (systemPowerIn: Double, batteryPower: Double) {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return (0, 0) }
        defer { IOObjectRelease(service) }

        guard let telemetry = IORegistryEntryCreateCFProperty(
            service,
            "PowerTelemetryData" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            return (0, 0)
        }

        let sysPowerIn = doubleFromAny(telemetry["SystemPowerIn"])
        let battPower = doubleFromAny(telemetry["BatteryPower"])

        // PowerTelemetryData values are in mW, convert to W
        return (sysPowerIn / 1000.0, battPower / 1000.0)
    }

    // MARK: - IOKit Helpers

    /// Decide whether an internal battery is fitted from IOKit registry values.
    ///
    /// Each argument is the value of the corresponding `AppleSmartBattery` registry
    /// key, or `-1` when the key is absent (see `intFromRegistry`). `BatteryInstalled`
    /// is the most reliable signal across Mac models; the legacy `BatteryPresent` /
    /// `BuiltIn` keys are absent on recent Apple Silicon Macs.
    ///
    /// - Returns: `false` when the keys are altogether absent (a battery-less
    ///   desktop) or `BatteryInstalled` is explicitly `0`; otherwise `true`.
    package nonisolated static func hasInternalBattery(
        batteryPresent: Int,
        builtIn: Int,
        batteryInstalled: Int
    ) -> Bool {
        let anyKeyPresent = batteryPresent >= 0 || builtIn >= 0 || batteryInstalled >= 0
        guard anyKeyPresent else { return false }   // desktop without internal battery
        if batteryInstalled == 0 { return false }    // explicitly no battery installed
        return true
    }

    private nonisolated static func intFromRegistry(_ service: io_service_t, _ key: String) -> Int {
        guard let value = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return -1
        }
        if let num = value as? Int { return num }
        if let num = value as? Int64 { return Int(num) }
        if let num = value as? NSNumber { return num.intValue }
        return -1
    }

    private nonisolated static func doubleFromRegistry(_ service: io_service_t, _ key: String) -> Double {
        guard let value = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() else {
            return 0
        }
        return doubleFromAny(value)
    }

    private nonisolated static func doubleFromAny(_ value: Any?) -> Double {
        switch value {
        case let v as Double: return v
        case let v as Float: return Double(v)
        case let v as Int: return Double(v)
        case let v as Int64: return Double(v)
        case let v as UInt64: return Double(v)
        case let v as NSNumber: return v.doubleValue
        default: return 0
        }
    }

    /// Format watt value for display.
    private nonisolated static func wattString(_ watts: Double) -> String {
        if watts == 0 { return "0 W" }
        if abs(watts) < 10 {
            return String(format: "%.2f W", watts)
        }
        return String(format: "%.1f W", watts)
    }
}
