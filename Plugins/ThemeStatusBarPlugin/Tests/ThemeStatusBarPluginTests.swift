import Testing
import LumiKernel
@testable import ThemeStatusBarPlugin

@MainActor
struct ThemeStatusBarPluginTests {
    @Test func metadata() {
        #expect(ThemeStatusBarPlugin.info.id == "com.coffic.lumi.plugin.theme-status-bar")
        #expect(ThemeStatusBarPlugin.info.order == 76)
    }

    @Test func hidesStatusItemWithoutThemeService() {
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )

        #expect(ThemeStatusBarPlugin.statusBarItems(context: context).isEmpty)
    }
}
