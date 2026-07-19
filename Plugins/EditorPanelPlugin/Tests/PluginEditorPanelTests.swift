@testable import EditorPanelPlugin
@testable import EditorService
import LumiCoreKit
import Testing

@Test func editorPanelPluginInfo() async throws {
    #expect(EditorPanelPlugin.info.id == "LumiEditor")
}

@MainActor
@Test func editorPanelPluginViewContainerRequiresEditorService() async throws {
    let core = EditorCore()
    let containersWithoutEditor = EditorPanelPlugin.viewContainers(
        lumiCore: LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    )
    #expect(containersWithoutEditor.isEmpty)

    let containers = EditorPanelPlugin.viewContainers(
        lumiCore: LumiPluginContext(
            activeSectionID: "LumiEditor",
            activeSectionTitle: "Editor",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiEditorServicing.self, core)
            }
        )
    )
    #expect(containers.count == 1)
    #expect(containers[0].showsPanelChrome == true)
    #expect(containers[0].showsRail == true)
}
