import Foundation
import Testing
@testable import DeviceInfoPlugin

struct BatteryModelsTests {
    @Test
    func batteryReadingEmptyDefaults() {
        let empty = BatteryReading.empty
        #expect(empty.level == 0)
        #expect(empty.isCharging == false)
        #expect(empty.isCharged == false)
        #expect(empty.isACConnected == false)
        #expect(empty.cycleCount == 0)
        #expect(empty.hasBattery == false)
        #expect(empty.powerSource == .acPower)
        #expect(empty.chargeState == .acOnly)
    }

    @Test
    func batteryDataPointIdentifiable() {
        let point = BatteryDataPoint(timestamp: 1000, watts: 5.5)
        #expect(point.id == 1000)
        #expect(point.watts == 5.5)
    }

    @Test
    func batteryDataPointCodable() throws {
        let point = BatteryDataPoint(timestamp: 1234, watts: 12.3)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(BatteryDataPoint.self, from: data)
        #expect(decoded == point)
    }

    @Test
    func batteryDataPointEquatable() {
        let a = BatteryDataPoint(timestamp: 1, watts: 2)
        let b = BatteryDataPoint(timestamp: 1, watts: 2)
        let c = BatteryDataPoint(timestamp: 1, watts: 3)
        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func batteryTimeRangeAllCases() {
        #expect(BatteryTimeRange.allCases.count == 4)
        #expect(BatteryTimeRange.minute1.duration == 60)
        #expect(BatteryTimeRange.minute5.duration == 300)
        #expect(BatteryTimeRange.minute30.duration == 1800)
        #expect(BatteryTimeRange.hour1.duration == 3600)
    }

    @Test
    func batteryTimeRangeId() {
        #expect(BatteryTimeRange.minute1.id == "minute1")
        #expect(BatteryTimeRange.hour1.id == "hour1")
    }

    @Test
    func batteryPowerSourceRawValues() {
        #expect(BatteryPowerSource.battery.rawValue == "Battery Power")
        #expect(BatteryPowerSource.acPower.rawValue == "AC Power")
        #expect(BatteryPowerSource.ups.rawValue == "UPS Power")
    }

    @Test
    func batteryChargeStateRawValues() {
        #expect(BatteryChargeState.notCharging.rawValue == "notCharging")
        #expect(BatteryChargeState.charging.rawValue == "charging")
        #expect(BatteryChargeState.charged.rawValue == "charged")
        #expect(BatteryChargeState.acOnly.rawValue == "acOnly")
    }
}
