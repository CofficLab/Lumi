import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeVscodeLightPlugin

@MainActor
struct ThemeVscodeLightPluginTests {
    @Test func metadata() {
        #expect(ThemeVscodeLightPlugin.info.id == "com.coffic.lumi.plugin.theme.vscode-light")
        #expect(ThemeVscodeLightPlugin.info.displayName.isEmpty == false)
        #expect(ThemeVscodeLightPlugin.info.order == 130)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVscodeLightPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "vscode-light")
        #expect(contributions[0].editorThemeId == "vscode-light")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeVscodeLightPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeVscodeLightPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
