import Testing
@testable import PluginAppManager

@Test func pluginMetadata() async throws {
    #expect(AppManagerPlugin.id == "AppManager")
    #expect(AppManagerPlugin.navigationId == "app_manager")
    #expect(AppManagerPlugin.iconName == "apps.ipad")
}
