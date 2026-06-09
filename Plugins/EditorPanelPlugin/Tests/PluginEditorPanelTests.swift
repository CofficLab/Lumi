@testable import EditorPanelPlugin
import Testing

@Test func editorPanelPluginInfo() async throws {
    #expect(EditorPanelPlugin.info.id == "LumiEditor")
}

@Test func editorPanelPluginViewContainerRequiresBootstrap() async throws {
    let containers = await EditorPanelPlugin.viewContainers(
        context: LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    )
    #expect(containers.isEmpty)
}
