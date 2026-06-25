import Testing
@testable import DeviceInfoPlugin

@MainActor
struct BatteryServiceTests {
    @Test
    func healthLabelGood() {
        let svc = BatteryService()
        svc.healthPercentage = 90
        #expect(svc.healthLabel == "Good")
    }

    @Test
    func healthLabelFair() {
        let svc = BatteryService()
        svc.healthPercentage = 70
        #expect(svc.healthLabel == "Fair")
    }

    @Test
    func healthLabelPoor() {
        let svc = BatteryService()
        svc.healthPercentage = 50
        #expect(svc.healthLabel == "Poor")
    }

    @Test
    func healthLabelBoundary80() {
        let svc = BatteryService()
        svc.healthPercentage = 80
        #expect(svc.healthLabel == "Good")
    }

    @Test
    func healthLabelBoundary60() {
        let svc = BatteryService()
        svc.healthPercentage = 60
        #expect(svc.healthLabel == "Fair")
    }

    @Test
    func chargeStateDescriptionNotCharging() {
        let svc = BatteryService()
        svc.chargeState = .notCharging
        svc.hasBattery = true
        #expect(svc.chargeStateDescription == "Not Charging")
    }

    @Test
    func chargeStateDescriptionNotChargingNoBattery() {
        let svc = BatteryService()
        svc.chargeState = .notCharging
        svc.hasBattery = false
        #expect(svc.chargeStateDescription == "AC Power")
    }

    @Test
    func chargeStateDescriptionCharging() {
        let svc = BatteryService()
        svc.chargeState = .charging
        #expect(svc.chargeStateDescription == "Charging")
    }

    @Test
    func chargeStateDescriptionCharged() {
        let svc = BatteryService()
        svc.chargeState = .charged
        #expect(svc.chargeStateDescription == "Fully Charged")
    }

    @Test
    func chargeStateDescriptionACOnly() {
        let svc = BatteryService()
        svc.chargeState = .acOnly
        #expect(svc.chargeStateDescription == "AC Power")
    }

    @Test
    func wattsString() {
        let svc = BatteryService()
        svc.watts = 15.5
        #expect(svc.wattsString == "15.5 W")
    }

    @Test
    func wattsStringSmall() {
        let svc = BatteryService()
        svc.watts = 5.23
        #expect(svc.wattsString == "5.23 W")
    }

    @Test
    func wattsStringZero() {
        let svc = BatteryService()
        svc.watts = 0
        #expect(svc.wattsString == "0 W")
    }

    @Test
    func adapterWattsStringPositive() {
        let svc = BatteryService()
        svc.adapterWatts = 65.0
        #expect(svc.adapterWattsString == "65.0 W")
    }

    @Test
    func adapterWattsStringZero() {
        let svc = BatteryService()
        svc.adapterWatts = 0
        #expect(svc.adapterWattsString == "—")
    }

    @Test
    func systemPowerInStringPositive() {
        let svc = BatteryService()
        svc.systemPowerIn = 45.3
        #expect(svc.systemPowerInString == "45.3 W")
    }

    @Test
    func systemPowerInStringZero() {
        let svc = BatteryService()
        svc.systemPowerIn = 0
        #expect(svc.systemPowerInString == "—")
    }

    @Test
    func temperatureStringPositive() {
        let svc = BatteryService()
        svc.temperature = 35.2
        #expect(svc.temperatureString == "35.2°C")
    }

    @Test
    func temperatureStringZero() {
        let svc = BatteryService()
        svc.temperature = 0
        #expect(svc.temperatureString == "—")
    }

    // MARK: - hasInternalBattery

    @Test
    func hasInternalBatteryAppleSiliconLaptop() {
        // Recent Apple Silicon Macs lack BatteryPresent/BuiltIn but expose
        // BatteryInstalled=1. Previously misdetected as a battery-less desktop.
        #expect(BatteryService.hasInternalBattery(batteryPresent: -1, builtIn: -1, batteryInstalled: 1) == true)
    }

    @Test
    func hasInternalBatteryIntelLaptop() {
        #expect(BatteryService.hasInternalBattery(batteryPresent: 1, builtIn: 1, batteryInstalled: 1) == true)
    }

    @Test
    func hasInternalBatteryDesktop() {
        // A desktop without an internal battery exposes none of the keys.
        #expect(BatteryService.hasInternalBattery(batteryPresent: -1, builtIn: -1, batteryInstalled: -1) == false)
    }

    @Test
    func hasInternalBatteryExplicitlyAbsent() {
        // BatteryInstalled=0 means no battery installed even if legacy keys exist.
        #expect(BatteryService.hasInternalBattery(batteryPresent: -1, builtIn: -1, batteryInstalled: 0) == false)
    }
}
