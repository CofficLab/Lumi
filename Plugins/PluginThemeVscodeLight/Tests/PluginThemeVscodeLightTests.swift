import Testing
@testable import PluginThemeVscodeLight

@MainActor
struct PluginThemeVscodeLightTests {
    @Test func metadata() {
        #expect(ThemeVscodeLightPlugin.id == "vscode-light")
        #expect(ThemeVscodeLightPlugin.displayName.isEmpty == false)
        #expect(ThemeVscodeLightPlugin.description.isEmpty == false)
        #expect(ThemeVscodeLightPlugin.iconName.isEmpty == false)
        #expect(ThemeVscodeLightPlugin.category == .theme)
        #expect(ThemeVscodeLightPlugin.order == 130)
        #expect(ThemeVscodeLightPlugin.shared.instanceLabel == ThemeVscodeLightPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVscodeLightPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
