import Testing
@testable import PluginThemeSummer

@MainActor
struct PluginThemeSummerTests {
    @Test func metadata() {
        #expect(ThemeSummerPlugin.id == "summer")
        #expect(ThemeSummerPlugin.displayName.isEmpty == false)
        #expect(ThemeSummerPlugin.description.isEmpty == false)
        #expect(ThemeSummerPlugin.iconName.isEmpty == false)
        #expect(ThemeSummerPlugin.category == .theme)
        #expect(ThemeSummerPlugin.order == 125)
        #expect(ThemeSummerPlugin.shared.instanceLabel == ThemeSummerPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeSummerPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
