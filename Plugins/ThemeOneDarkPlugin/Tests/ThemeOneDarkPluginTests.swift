import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeOneDarkPlugin

@MainActor
struct ThemeOneDarkPluginTests {
    @Test func metadata() {
        #expect(ThemeOneDarkPlugin.info.id == "com.coffic.lumi.plugin.theme.one-dark")
        #expect(ThemeOneDarkPlugin.info.displayName.isEmpty == false)
        #expect(ThemeOneDarkPlugin.info.order == 131)
    }

    @Test func contributesTheme() {
        let contributions = ThemeOneDarkPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "one-dark")
        #expect(contributions[0].editorThemeId == "one-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeOneDarkPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeOneDarkPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
