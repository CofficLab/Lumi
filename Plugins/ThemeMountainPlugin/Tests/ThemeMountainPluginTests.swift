import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeMountainPlugin

@MainActor
struct ThemeMountainPluginTests {
    @Test func metadata() {
        #expect(ThemeMountainPlugin.info.id == "com.coffic.lumi.plugin.theme.mountain")
        #expect(ThemeMountainPlugin.info.displayName.isEmpty == false)
        #expect(ThemeMountainPlugin.info.order == 129)
    }

    @Test func contributesTheme() {
        let contributions = ThemeMountainPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "mountain")
        #expect(contributions[0].editorThemeId == "mountain")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeMountainPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeMountainPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
