import Testing
@testable import ThemeVoidPlugin

@MainActor
struct ThemeVoidPluginTests {
    @Test func metadata() {
        #expect(ThemeVoidPlugin.id == "void")
        #expect(ThemeVoidPlugin.displayName.isEmpty == false)
        #expect(ThemeVoidPlugin.description.isEmpty == false)
        #expect(ThemeVoidPlugin.iconName.isEmpty == false)
        #expect(ThemeVoidPlugin.category == .theme)
        #expect(ThemeVoidPlugin.order == 123)
        #expect(ThemeVoidPlugin.shared.instanceLabel == ThemeVoidPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeVoidPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
