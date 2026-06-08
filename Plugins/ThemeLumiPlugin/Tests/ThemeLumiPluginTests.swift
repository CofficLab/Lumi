import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeLumiPlugin

@MainActor
struct ThemeLumiPluginTests {
    @Test func metadata() {
        #expect(ThemeLumiPlugin.info.id == "com.coffic.lumi.plugin.theme.lumi")
        #expect(ThemeLumiPlugin.info.displayName.isEmpty == false)
        #expect(ThemeLumiPlugin.info.description.isEmpty == false)
        #expect(ThemeLumiPlugin.info.order == 100)
    }

    @Test func contributesTheme() {
        let contributions = ThemeLumiPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "lumi")
        #expect(contributions[0].editorThemeId == "lumi-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeLumiPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeLumiPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
