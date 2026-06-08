import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeSpringPlugin

@MainActor
struct ThemeSpringPluginTests {
    @Test func metadata() {
        #expect(ThemeSpringPlugin.info.id == "com.coffic.lumi.plugin.theme.spring")
        #expect(ThemeSpringPlugin.info.displayName.isEmpty == false)
        #expect(ThemeSpringPlugin.info.order == 124)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSpringPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "spring")
        #expect(contributions[0].editorThemeId == "spring")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeSpringPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeSpringPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
