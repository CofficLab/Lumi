import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeRiverPlugin

@MainActor
struct ThemeRiverPluginTests {
    @Test func metadata() {
        #expect(ThemeRiverPlugin.info.id == "com.coffic.lumi.plugin.theme.river")
        #expect(ThemeRiverPlugin.info.displayName.isEmpty == false)
        #expect(ThemeRiverPlugin.info.order == 130)
    }

    @Test func contributesTheme() {
        let contributions = ThemeRiverPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "river")
        #expect(contributions[0].editorThemeId == "river")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeRiverPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeRiverPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
