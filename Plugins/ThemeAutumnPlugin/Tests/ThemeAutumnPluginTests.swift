import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeAutumnPlugin

@MainActor
struct ThemeAutumnPluginTests {
    @Test func metadata() {
        #expect(ThemeAutumnPlugin.info.id == "com.coffic.lumi.plugin.theme.autumn")
        #expect(ThemeAutumnPlugin.info.displayName.isEmpty == false)
        #expect(ThemeAutumnPlugin.info.order == 126)
    }

    @Test func contributesTheme() {
        let contributions = ThemeAutumnPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "autumn")
        #expect(contributions[0].editorThemeId == "autumn")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeAutumnPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeAutumnPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
