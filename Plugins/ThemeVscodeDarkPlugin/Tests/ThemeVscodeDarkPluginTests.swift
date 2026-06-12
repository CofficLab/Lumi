import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeVscodeDarkPlugin

@MainActor
struct ThemeVscodeDarkPluginTests {
    @Test func metadata() {
        #expect(ThemeVscodeDarkPlugin.info.id == "com.coffic.lumi.plugin.theme.vscode-dark")
        #expect(ThemeVscodeDarkPlugin.info.displayName.isEmpty == false)
        #expect(ThemeVscodeDarkPlugin.info.order == 129)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVscodeDarkPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "vscode-dark")
        #expect(contributions[0].editorThemeId == "vscode-dark")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeVscodeDarkPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeVscodeDarkPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
