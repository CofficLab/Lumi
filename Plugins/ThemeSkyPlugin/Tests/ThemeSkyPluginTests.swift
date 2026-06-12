import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeSkyPlugin

@MainActor
struct ThemeSkyPluginTests {
    @Test func metadata() {
        #expect(ThemeSkyPlugin.info.id == "com.coffic.lumi.plugin.theme.sky")
        #expect(ThemeSkyPlugin.info.displayName.isEmpty == false)
        #expect(ThemeSkyPlugin.info.order == 120)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSkyPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "sky")
        #expect(contributions[0].editorThemeId == "sky-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeSkyPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeSkyPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
