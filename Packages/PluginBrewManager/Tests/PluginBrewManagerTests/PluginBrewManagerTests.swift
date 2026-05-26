import Testing
@testable import PluginBrewManager

struct PluginBrewManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(BrewManagerPlugin.id == "BrewManager")
        #expect(BrewManagerPlugin.iconName == "mug.fill")
    }
}
