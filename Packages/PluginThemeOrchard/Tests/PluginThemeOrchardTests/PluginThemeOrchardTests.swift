import Testing
@testable import PluginThemeOrchard

@MainActor
struct PluginThemeOrchardTests {
    @Test func metadata() {
        #expect(ThemeOrchardPlugin.id == "orchard")
        #expect(ThemeOrchardPlugin.displayName.isEmpty == false)
        #expect(ThemeOrchardPlugin.description.isEmpty == false)
        #expect(ThemeOrchardPlugin.iconName.isEmpty == false)
        #expect(ThemeOrchardPlugin.category == .theme)
        #expect(ThemeOrchardPlugin.order == 128)
        #expect(ThemeOrchardPlugin.shared.instanceLabel == ThemeOrchardPlugin.id)
    }

    @Test func contributesTheme() {
        let contributions = ThemeOrchardPlugin.shared.addThemeContributions()
        #expect(contributions.isEmpty == false)
    }
}
