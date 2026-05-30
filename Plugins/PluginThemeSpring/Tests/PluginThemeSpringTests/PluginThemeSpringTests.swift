import Testing
@testable import PluginThemeSpring

@MainActor
struct PluginThemeSpringTests {
    @Test func metadata() {
        #expect(ThemeSpringPlugin.id == "spring")
        #expect(ThemeSpringPlugin.displayName.isEmpty == false)
        #expect(ThemeSpringPlugin.description.isEmpty == false)
        #expect(ThemeSpringPlugin.iconName.isEmpty == false)
        #expect(ThemeSpringPlugin.category == .theme)
        #expect(ThemeSpringPlugin.order == 124)
        #expect(ThemeSpringPlugin.shared.instanceLabel == ThemeSpringPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSpringPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
