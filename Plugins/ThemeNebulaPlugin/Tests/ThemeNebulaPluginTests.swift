import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeNebulaPlugin

@MainActor
struct ThemeNebulaPluginTests {
    @Test func metadata() {
        #expect(ThemeNebulaPlugin.info.id == "com.coffic.lumi.plugin.theme.nebula")
        #expect(ThemeNebulaPlugin.info.displayName.isEmpty == false)
        #expect(ThemeNebulaPlugin.info.order == 122)
    }

    @Test func contributesTheme() {
        let contributions = ThemeNebulaPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "nebula")
        #expect(contributions[0].editorThemeId == "nebula")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeNebulaPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeNebulaPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
