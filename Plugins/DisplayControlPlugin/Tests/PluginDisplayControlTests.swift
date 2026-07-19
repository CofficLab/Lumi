import Testing
import LumiKernel
@testable import DisplayControlPlugin

@MainActor
@Test("Plugin info is valid")
func pluginInfoIsValid() {
    let info = DisplayControlPlugin.info
    #expect(!info.id.isEmpty)
    #expect(!info.displayName.isEmpty)
    #expect(!info.description.isEmpty)
    #expect(info.id == "com.coffic.lumi.plugin.display-control")
}

@Test("DisplayControlKind defaults are in valid range")
func controlKindDefaults() {
    #expect(DisplayControlKind.brightness.defaultValue >= 0)
    #expect(DisplayControlKind.brightness.defaultValue <= 100)
    #expect(DisplayControlKind.volume.defaultValue >= 0)
    #expect(DisplayControlKind.volume.defaultValue <= 100)
    #expect(DisplayControlKind.contrast.defaultValue >= 0)
    #expect(DisplayControlKind.contrast.defaultValue <= 100)
}
