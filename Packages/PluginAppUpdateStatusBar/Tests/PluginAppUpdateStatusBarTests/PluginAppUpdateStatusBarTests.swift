import Testing
@testable import PluginAppUpdateStatusBar

struct PluginAppUpdateStatusBarTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(AppUpdateStatusBarPlugin.id == "AppUpdateStatusBar")
        #expect(AppUpdateStatusBarPlugin.iconName == "arrow.down.circle")
    }
}
