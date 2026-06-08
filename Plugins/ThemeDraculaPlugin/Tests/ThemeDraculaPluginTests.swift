import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeDraculaPlugin

@MainActor
struct ThemeDraculaPluginTests {
    @Test func metadata() {
        #expect(ThemeDraculaPlugin.info.id == "com.coffic.lumi.plugin.theme.dracula")
        #expect(ThemeDraculaPlugin.info.displayName.isEmpty == false)
        #expect(ThemeDraculaPlugin.info.order == 132)
    }

    @Test func contributesTheme() {
        let contributions = ThemeDraculaPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "dracula")
        #expect(contributions[0].editorThemeId == "dracula")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeDraculaPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeDraculaPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
