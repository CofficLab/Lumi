import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeVoidPlugin

@MainActor
struct ThemeVoidPluginTests {
    @Test func metadata() {
        #expect(ThemeVoidPlugin.info.id == "com.coffic.lumi.plugin.theme.void")
        #expect(ThemeVoidPlugin.info.displayName.isEmpty == false)
        #expect(ThemeVoidPlugin.info.order == 123)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVoidPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "void")
        #expect(contributions[0].editorThemeId == "void")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeVoidPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeVoidPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
