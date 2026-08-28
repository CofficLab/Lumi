import CoreGraphics
import Testing
@testable import DisplayControlPlugin

// MARK: - DisplayDDCBridge Safety Tests
// These tests verify that DDCBridge handles all edge cases gracefully
// without crashing — the same scenario that caused the original nil crash.

@Test("DisplayDDCBridge returns nil/false when no service exists for display")
func bridgeReturnsNilWithoutService() {
    let bridge = DisplayDDCBridge()
    let fakeDisplayID: CGDirectDisplayID = 999_999

    // No refresh called — should have no services, no crash
    #expect(!bridge.hasService(for: fakeDisplayID))
    #expect(bridge.read(.brightness, displayID: fakeDisplayID) == nil)
    #expect(bridge.read(.volume, displayID: fakeDisplayID) == nil)
    #expect(bridge.read(.contrast, displayID: fakeDisplayID) == nil)
    #expect(bridge.write(50, for: .brightness, displayID: fakeDisplayID) == false)
    #expect(bridge.write(50, for: .volume, displayID: fakeDisplayID) == false)
    #expect(bridge.write(50, for: .contrast, displayID: fakeDisplayID) == false)
}

@Test("DisplayDDCBridge returns nil after refresh with empty display IDs")
func bridgeReturnsNilAfterEmptyRefresh() {
    let bridge = DisplayDDCBridge()
    bridge.refresh(displayIDs: [])

    #expect(!bridge.hasService(for: 0))
    #expect(bridge.read(.brightness, displayID: 0) == nil)
}

@Test("DisplayDDCBridge handles refresh with non-existent display IDs gracefully")
func bridgeRefreshWithInvalidIDs() {
    let bridge = DisplayDDCBridge()
    // These display IDs don't exist on the system — should not crash
    bridge.refresh(displayIDs: [999_888, 777_666])

    #expect(!bridge.hasService(for: 999_888))
    #expect(!bridge.hasService(for: 777_666))
    #expect(bridge.read(.brightness, displayID: 999_888) == nil)
    #expect(bridge.write(50, for: .volume, displayID: 777_666) == false)
}

@Test("DisplayDDCBridge multiple refreshes do not crash")
func bridgeMultipleRefreshes() {
    let bridge = DisplayDDCBridge()
    // Repeated refreshes should be safe — no crash, no leak
    for _ in 0..<5 {
        bridge.refresh(displayIDs: [])
    }
    #expect(bridge.read(.brightness, displayID: 0) == nil)
}

@Test("DisplayDDCBridge read/write all control kinds without service returns nil/false")
func bridgeAllControlsWithoutService() {
    let bridge = DisplayDDCBridge()
    let fakeID: CGDirectDisplayID = 42

    for control: DisplayControlKind in [.brightness, .volume, .contrast] {
        #expect(bridge.read(control, displayID: fakeID) == nil)
        #expect(bridge.write(50, for: control, displayID: fakeID) == false)
    }
}

@Test("DisplayDDCBridge write clamps out-of-range values without crashing")
func bridgeWriteClampsValues() {
    let bridge = DisplayDDCBridge()
    let fakeDisplayID: CGDirectDisplayID = 123

    // Values outside 0–100 should not crash, just fail gracefully (no service)
    #expect(bridge.write(-50, for: .brightness, displayID: fakeDisplayID) == false)
    #expect(bridge.write(200, for: .brightness, displayID: fakeDisplayID) == false)
}

@Test("DisplayDDCBridge can be deallocated safely after refresh")
func bridgeDeallocation() {
    // Ensure no dangling pointers or leaks when bridge is deinitialized
    autoreleasepool {
        let bridge = DisplayDDCBridge()
        bridge.refresh(displayIDs: [999_000])
        _ = bridge.read(.brightness, displayID: 999_000)
        _ = bridge.write(50, for: .volume, displayID: 999_000)
    }
    // If we reach here without a crash, the test passes
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
