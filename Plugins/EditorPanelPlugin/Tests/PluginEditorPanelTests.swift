import Testing
@testable import EditorPanelPlugin

@Test func packageLoads() async throws {
    #expect(EditorPlugin.id == "LumiEditor")
}

@MainActor
@Test func editorContainerShowsBottomPanel() async throws {
    let container = EditorPlugin.shared.addViewContainer()

    #expect(container?.showsProjectToolbar == true)
    #expect(container?.showChat == .narrow)
    #expect(container?.showsRail == true)
    #expect(container?.showsBottomPanel == true)
}
