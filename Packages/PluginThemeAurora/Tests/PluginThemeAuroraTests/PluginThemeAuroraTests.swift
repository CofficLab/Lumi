import Testing
@testable import PluginThemeAurora

@Test func pluginMetadata() async throws {
    #expect(ThemeAuroraPlugin.id == "aurora")
    #expect(ThemeAuroraPlugin.iconName == "sparkles")
    #expect(ThemeAuroraPlugin.order == 121)
}
