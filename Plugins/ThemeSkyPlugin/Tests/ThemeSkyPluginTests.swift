import Testing
@testable import ThemeSkyPlugin

@MainActor
struct ThemeSkyPluginTests {
    @Test func metadata() {
        #expect(ThemeSkyPlugin.id == "sky")
        #expect(ThemeSkyPlugin.displayName.isEmpty == false)
        #expect(ThemeSkyPlugin.description.isEmpty == false)
        #expect(ThemeSkyPlugin.iconName.isEmpty == false)
        #expect(ThemeSkyPlugin.category == .theme)
        #expect(ThemeSkyPlugin.order == 120)
        #expect(ThemeSkyPlugin.shared.instanceLabel == ThemeSkyPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSkyPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
