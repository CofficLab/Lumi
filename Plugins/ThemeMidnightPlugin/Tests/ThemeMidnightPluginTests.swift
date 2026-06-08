import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeMidnightPlugin

@MainActor
struct ThemeMidnightPluginTests {
    @Test func metadata() {
        #expect(ThemeMidnightPlugin.info.id == "com.coffic.lumi.plugin.theme.midnight")
        #expect(ThemeMidnightPlugin.info.displayName.isEmpty == false)
        #expect(ThemeMidnightPlugin.info.order == 120)
    }

    @Test func contributesTheme() {
        let contributions = ThemeMidnightPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "midnight")
        #expect(contributions[0].editorThemeId == "midnight")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeMidnightPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeMidnightPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
