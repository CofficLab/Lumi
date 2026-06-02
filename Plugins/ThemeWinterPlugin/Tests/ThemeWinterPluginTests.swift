import Testing
@testable import ThemeWinterPlugin

@MainActor
struct ThemeWinterPluginTests {
    @Test func metadata() {
        #expect(ThemeWinterPlugin.id == "winter")
        #expect(ThemeWinterPlugin.displayName.isEmpty == false)
        #expect(ThemeWinterPlugin.description.isEmpty == false)
        #expect(ThemeWinterPlugin.iconName.isEmpty == false)
        #expect(ThemeWinterPlugin.category == .theme)
        #expect(ThemeWinterPlugin.order == 127)
        #expect(ThemeWinterPlugin.shared.instanceLabel == ThemeWinterPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeWinterPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
