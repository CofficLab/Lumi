@testable import EditorPanelPlugin
@testable import EditorService
import LumiCoreKit
import Testing

@Test func editorPanelPluginInfo() async throws {
    #expect(EditorPanelPlugin.info.id == "LumiEditor")
}

@Test func editorPanelPluginViewContainerRequiresEditorService() async throws {
    let core = EditorCore()
    let containersWithoutEditor = await EditorPanelPlugin.viewContainers(
        context: LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    )
    #expect(containersWithoutEditor.isEmpty)

    let containers = await EditorPanelPlugin.viewContainers(
        context: LumiPluginContext(
            activeSectionID: "LumiEditor",
            activeSectionTitle: "Editor",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiEditorServicing.self, core)
            }
        )
    )
    #expect(containers.count == 1)
}
