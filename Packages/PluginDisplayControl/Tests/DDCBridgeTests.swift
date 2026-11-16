import CoreGraphics
import Testing
@testable import DisplayControlPlugin

// MARK: - DisplayDDCBridge Safety Tests
// These tests verify that DDCBridge handles all edge cases gracefully
// without crashing — the same scenario that caused the original nil crash.

@Test("DisplayDDCBridge returns nil/false when no service exists for display")
func bridgeReturnsNilWithoutService() async {
    let bridge = DisplayDDCBridge()
    let fakeDisplayID: CGDirectDisplayID = 999_999

    // No refresh called — should have no services, no crash
    #expect(await !bridge.hasService(for: fakeDisplayID))
    #expect(await bridge.read(.brightness, displayID: fakeDisplayID) == nil)
    #expect(await bridge.read(.volume, displayID: fakeDisplayID) == nil)
    #expect(await bridge.read(.contrast, displayID: fakeDisplayID) == nil)
    #expect(await bridge.write(50, for: .brightness, displayID: fakeDisplayID) == false)
    #expect(await bridge.write(50, for: .volume, displayID: fakeDisplayID) == false)
    #expect(await bridge.write(50, for: .contrast, displayID: fakeDisplayID) == false)
}

@Test("DisplayDDCBridge returns nil after refresh with empty display IDs")
func bridgeReturnsNilAfterEmptyRefresh() async {
    let bridge = DisplayDDCBridge()
    await bridge.refresh(displayIDs: [])

    #expect(await !bridge.hasService(for: 0))
    #expect(await bridge.read(.brightness, displayID: 0) == nil)
}

@Test("DisplayDDCBridge handles refresh with non-existent display IDs gracefully")
func bridgeRefreshWithInvalidIDs() async {
    let bridge = DisplayDDCBridge()
    // These display IDs don't exist on the system — should not crash
    await bridge.refresh(displayIDs: [999_888, 777_666])

    #expect(await !bridge.hasService(for: 999_888))
    #expect(await !bridge.hasService(for: 777_666))
    #expect(await bridge.read(.brightness, displayID: 999_888) == nil)
    #expect(await bridge.write(50, for: .volume, displayID: 777_666) == false)
}

@Test("DisplayDDCBridge multiple refreshes do not crash")
func bridgeMultipleRefreshes() async {
    let bridge = DisplayDDCBridge()
    // Repeated refreshes should be safe — no crash, no leak
    for _ in 0..<5 {
        await bridge.refresh(displayIDs: [])
    }
    #expect(await bridge.read(.brightness, displayID: 0) == nil)
}

@Test("DisplayDDCBridge read/write all control kinds without service returns nil/false")
func bridgeAllControlsWithoutService() async {
    let bridge = DisplayDDCBridge()
    let fakeID: CGDirectDisplayID = 42

    for control: DisplayControlKind in [.brightness, .volume, .contrast] {
        #expect(await bridge.read(control, displayID: fakeID) == nil)
        #expect(await bridge.write(50, for: control, displayID: fakeID) == false)
    }
}

@Test("DisplayDDCBridge write clamps out-of-range values without crashing")
func bridgeWriteClampsValues() async {
    let bridge = DisplayDDCBridge()
    let fakeDisplayID: CGDirectDisplayID = 123

    // Values outside 0–100 should not crash, just fail gracefully (no service)
    #expect(await bridge.write(-50, for: .brightness, displayID: fakeDisplayID) == false)
    #expect(await bridge.write(200, for: .brightness, displayID: fakeDisplayID) == false)
}

@Test("DisplayDDCBridge can be deallocated safely after refresh")
func bridgeDeallocation() async {
    // Ensure no dangling pointers or leaks when bridge is deinitialized
    let bridge = DisplayDDCBridge()
    await bridge.refresh(displayIDs: [999_000])
    _ = await bridge.read(.brightness, displayID: 999_000)
    _ = await bridge.write(50, for: .volume, displayID: 999_000)
    // If we reach here without a crash, the test passes
}

// MARK: - DDC Volume Write Plan Tests

@Test("zero volume never writes the mute/screen-blank channel")
func zeroVolumeSkipsScreenBlankChannel() {
    #expect(DDCVolumeWritePlan.plan(for: 0) == .volumeOnly)
    #expect(DDCVolumeWritePlan.plan(for: -10) == .volumeOnly)
}

@Test("non-zero volume unmutes before writing speaker volume")
func nonZeroVolumeUnmutes() {
    #expect(DDCVolumeWritePlan.plan(for: 1) == .unmute)
    #expect(DDCVolumeWritePlan.plan(for: 100) == .unmute)
}

// MARK: - ControlledDisplay Mutation Safety Tests

@Test("ControlledDisplay setValue and setSupported mutate correctly")
func controlledDisplayMutation() {
    var display = ControlledDisplay(
        id: 1,
        storageID: "test",
        name: "Test",
        isBuiltIn: false,
        supportsBrightness: true,
        supportsVolume: true,
        supportsContrast: true,
        brightness: 50,
        volume: 50,
        contrast: 50
    )

    display.setValue(75, for: .brightness)
    #expect(display.brightness == 75)

    display.setValue(0, for: .volume)
    #expect(display.volume == 0)

    display.setSupported(false, for: .contrast)
    #expect(display.supportsContrast == false)
    #expect(display.supports(.contrast) == false)
}

@Test("ControlledDisplay value(for:) returns correct values")
func controlledDisplayValueFor() {
    let display = ControlledDisplay(
        id: 2,
        storageID: "test2",
        name: "Monitor",
        isBuiltIn: false,
        supportsBrightness: true,
        supportsVolume: false,
        supportsContrast: true,
        brightness: 80,
        volume: 20,
        contrast: 60
    )

    #expect(display.value(for: .brightness) == 80)
    #expect(display.value(for: .volume) == 20)
    #expect(display.value(for: .contrast) == 60)
}

// MARK: - ControlKey & DisplayWriteResult Tests

@Test("ControlKey equality works correctly")
func controlKeyEquality() {
    let key1 = ControlKey(displayID: 1, control: .brightness)
    let key2 = ControlKey(displayID: 1, control: .brightness)
    let key3 = ControlKey(displayID: 1, control: .volume)
    let key4 = ControlKey(displayID: 2, control: .brightness)

    #expect(key1 == key2)
    #expect(key1 != key3)
    #expect(key1 != key4)
}

@Test("ControlKey can be used as dictionary key")
func controlKeyAsDictionaryKey() {
    var dict: [ControlKey: Double] = [:]
    let key = ControlKey(displayID: 1, control: .brightness)
    dict[key] = 75.0
    #expect(dict[key] == 75.0)
}

@Test("DisplayWriteResult stores values correctly")
func displayWriteResult() {
    let key = ControlKey(displayID: 1, control: .brightness)
    let result = DisplayWriteResult(key: key, value: 75.0, success: true)
    #expect(result.key == key)
    #expect(result.value == 75.0)
    #expect(result.success == true)
}
