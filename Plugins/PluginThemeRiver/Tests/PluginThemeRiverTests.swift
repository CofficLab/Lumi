import Testing
@testable import PluginThemeRiver

@MainActor
struct PluginThemeRiverTests {
    @Test func metadata() {
        #expect(ThemeRiverPlugin.id == "river")
        #expect(ThemeRiverPlugin.displayName.isEmpty == false)
        #expect(ThemeRiverPlugin.description.isEmpty == false)
        #expect(ThemeRiverPlugin.iconName.isEmpty == false)
        #expect(ThemeRiverPlugin.category == .theme)
        #expect(ThemeRiverPlugin.order == 130)
        #expect(ThemeRiverPlugin.shared.instanceLabel == ThemeRiverPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeRiverPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
