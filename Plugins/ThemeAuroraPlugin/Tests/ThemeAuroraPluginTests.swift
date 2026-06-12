import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeAuroraPlugin

@MainActor
struct ThemeAuroraPluginTests {
    @Test func metadata() {
        #expect(ThemeAuroraPlugin.info.id == "com.coffic.lumi.plugin.theme.aurora")
        #expect(ThemeAuroraPlugin.info.displayName.isEmpty == false)
        #expect(ThemeAuroraPlugin.info.order == 121)
    }

    @Test func contributesTheme() {
        let contributions = ThemeAuroraPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "aurora")
        #expect(contributions[0].editorThemeId == "aurora")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeAuroraPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeAuroraPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
