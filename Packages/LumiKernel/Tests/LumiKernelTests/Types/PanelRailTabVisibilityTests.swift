import Testing
@testable import LumiKernel

@Suite("PanelRailTabVisibility")
struct PanelRailTabVisibilityTests {
    @Test("always is visible in every container")
    func alwaysIsVisibleEverywhere() {
        let visibility = PanelRailTabVisibility.always

        #expect(visibility.isVisible(in: "chat") == true)
        #expect(visibility.isVisible(in: "story-writer") == true)
    }

    @Test("view container scope only matches its container")
    func viewContainerScopeMatchesOnlyTarget() {
        let visibility = PanelRailTabVisibility.viewContainer(id: "story-writer")

        #expect(visibility.isVisible(in: "story-writer") == true)
        #expect(visibility.isVisible(in: "chat") == false)
    }
}
