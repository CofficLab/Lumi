import Testing
@testable import PluginCaffeinate

@Test func pluginMetadata() async throws {
    #expect(CaffeinatePlugin.id == "Caffeinate")
    #expect(CaffeinatePlugin.navigationId == "caffeinate_settings")
    #expect(CaffeinatePlugin.iconName == "bolt")
}
