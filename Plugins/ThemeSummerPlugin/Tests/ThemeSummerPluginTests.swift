import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeSummerPlugin

@MainActor
struct ThemeSummerPluginTests {
    @Test func metadata() {
        #expect(ThemeSummerPlugin.info.id == "com.coffic.lumi.plugin.theme.summer")
        #expect(ThemeSummerPlugin.info.displayName.isEmpty == false)
        #expect(ThemeSummerPlugin.info.order == 125)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSummerPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "summer")
        #expect(contributions[0].editorThemeId == "summer")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeSummerPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeSummerPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
