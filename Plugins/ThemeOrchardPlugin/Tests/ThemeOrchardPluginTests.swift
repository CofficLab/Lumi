import Testing
import LumiCoreKit
import LumiUI
@testable import ThemeOrchardPlugin

@MainActor
struct ThemeOrchardPluginTests {
    @Test func metadata() {
        #expect(ThemeOrchardPlugin.info.id == "com.coffic.lumi.plugin.theme.orchard")
        #expect(ThemeOrchardPlugin.info.displayName.isEmpty == false)
        #expect(ThemeOrchardPlugin.info.order == 128)
    }

    @Test func contributesTheme() {
        let contributions = ThemeOrchardPlugin.themeContributions()
        #expect(contributions.count == 1)
        #expect(contributions[0].id == "orchard")
        #expect(contributions[0].editorThemeId == "orchard")
    }

    @Test func conformsToPluginAndThemeProvider() {
        let plugin = ThemeOrchardPlugin.self as any LumiPlugin.Type
        let provider = plugin as? any LumiUIThemeProviding.Type
        #expect(plugin.info.id == ThemeOrchardPlugin.info.id)
        #expect(provider?.themeContributions().count == 1)
    }
}
