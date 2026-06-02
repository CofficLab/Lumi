import Testing
@testable import PluginThemeLumi

@MainActor
struct PluginThemeLumiTests {
    @Test func metadata() {
        #expect(ThemeLumiPlugin.id == "lumi")
        #expect(ThemeLumiPlugin.displayName.isEmpty == false)
        #expect(ThemeLumiPlugin.description.isEmpty == false)
        #expect(ThemeLumiPlugin.iconName.isEmpty == false)
        #expect(ThemeLumiPlugin.category == .theme)
        #expect(ThemeLumiPlugin.order == 119)
        #expect(ThemeLumiPlugin.shared.instanceLabel == ThemeLumiPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeLumiPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
