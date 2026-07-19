import Foundation
import Testing
import LumiKernel
@testable import DisplayControlPlugin

@Test("Plugin info has correct identifier")
func pluginInfoIdentifier() {
    #expect(DisplayControlPlugin.info.id == "com.coffic.lumi.plugin.display-control")
}

@Test("Plugin info has correct display name")
func pluginInfoDisplayName() {
    let expected = LumiPluginLocalization.string("Display Control", bundle: .module, locale: Locale(identifier: "en"))
    #expect(DisplayControlPlugin.info.displayName == expected)
}

@Test("Plugin category is system")
func pluginCategory() {
    #expect(DisplayControlPlugin.category == .system)
}

@Test("Plugin policy is optIn")
func pluginPolicy() {
    #expect(DisplayControlPlugin.policy == .optIn)
}

@Test("Plugin iconName is display")
func pluginIconName() {
    #expect(DisplayControlPlugin.iconName == "display")
}

@Test("DisplayControlKind has correct cases")
func displayControlKinds() {
    let brightness = DisplayControlKind.brightness
    let contrast = DisplayControlKind.contrast
    let volume = DisplayControlKind.volume

    #expect(brightness.icon == "sun.max")
    #expect(contrast.icon == "circle.lefthalf.filled")
    #expect(volume.icon == "speaker.wave.2")
}

@Test("DisplayControlKind default values are correct")
func displayControlKindDefaultValues() {
    #expect(DisplayControlKind.brightness.defaultValue == 50)
    #expect(DisplayControlKind.volume.defaultValue == 40)
    #expect(DisplayControlKind.contrast.defaultValue == 75)
}

@Test("ControlledDisplay initializes correctly")
@MainActor
func controlledDisplayInit() {
    let display = ControlledDisplay(
        id: 1,
        storageID: "test-display",
        name: "Test Display",
        isBuiltIn: false,
        supportsBrightness: true,
        supportsVolume: true,
        supportsContrast: false,
        brightness: 75,
        volume: 30,
        contrast: 50
    )

    #expect(display.id == 1)
    #expect(display.name == "Test Display")
    #expect(display.isBuiltIn == false)
    #expect(display.supports(.brightness) == true)
    #expect(display.supports(.volume) == true)
    #expect(display.supports(.contrast) == false)
    #expect(display.brightness == 75)
    #expect(display.volume == 30)
    #expect(display.contrast == 50)
}
