import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeWinterPlugin

@MainActor
struct ThemeWinterPluginTests {
    @Test func metadata() {
        #expect(ThemeWinterPlugin.info.id == "com.coffic.lumi.plugin.theme.winter")
        #expect(ThemeWinterPlugin.info.displayName.isEmpty == false)
        #expect(ThemeWinterPlugin.info.order == 127)
    }

    @Test func contributesTheme() {
        let contributions = ThemeWinterPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "winter")
        #expect(contributions[0].editorThemeId == "winter")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeWinterPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeWinterPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
