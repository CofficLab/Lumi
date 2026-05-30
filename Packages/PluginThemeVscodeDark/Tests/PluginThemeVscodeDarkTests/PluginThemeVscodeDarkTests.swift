import Testing
@testable import PluginThemeVscodeDark

@MainActor
struct PluginThemeVscodeDarkTests {
    @Test func metadata() {
        #expect(ThemeVscodeDarkPlugin.id == "vscode-dark")
        #expect(ThemeVscodeDarkPlugin.displayName.isEmpty == false)
        #expect(ThemeVscodeDarkPlugin.description.isEmpty == false)
        #expect(ThemeVscodeDarkPlugin.iconName.isEmpty == false)
        #expect(ThemeVscodeDarkPlugin.category == .theme)
        #expect(ThemeVscodeDarkPlugin.order == 129)
        #expect(ThemeVscodeDarkPlugin.shared.instanceLabel == ThemeVscodeDarkPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVscodeDarkPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
