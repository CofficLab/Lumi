import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeGithubPlugin

@MainActor
struct ThemeGithubPluginTests {
    @Test func metadata() {
        #expect(ThemeGithubPlugin.info.id == "com.coffic.lumi.plugin.theme.github")
        #expect(ThemeGithubPlugin.info.displayName.isEmpty == false)
        #expect(ThemeGithubPlugin.info.order == 128)
    }

    @Test func contributesTheme() {
        let contributions = ThemeGithubPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "github")
        #expect(contributions[0].editorThemeId == "github")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeGithubPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeGithubPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
