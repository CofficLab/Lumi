import Testing
import LumiKernel
@testable import ThemeManagerPlugin

@MainActor
struct ThemeManagerPluginTests {
    @Test func metadata() {
        #expect(ThemeManagerPlugin.info.id == "com.coffic.lumi.plugin.theme-manager")
        #expect(ThemeManagerPlugin.info.order == 22)
    }

    @Test func hidesStatusItemWithoutThemeService() {
        let context = LumiPluginContext(
            activeSectionID: "test",
            activeSectionTitle: "Test"
        )

        #expect(ThemeManagerPlugin.statusBarItems(context: context).isEmpty)
    }
}
