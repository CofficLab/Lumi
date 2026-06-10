@testable import EditorPanelPlugin
@testable import EditorService
import EditorBottomProblemsPlugin
import EditorBreadcrumbNavPlugin
import EditorRailFileTreePlugin
import EditorTabStripPlugin
import LumiCoreKit
import Testing

@Test func editorPanelPluginInfo() async throws {
    #expect(EditorPanelPlugin.info.id == "LumiEditor")
}

@MainActor
@Test func editorPanelPluginViewContainerRequiresEditorService() async throws {
    let core = EditorCore()
    let containersWithoutEditor = EditorPanelPlugin.viewContainers(
        context: LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    )
    #expect(containersWithoutEditor.isEmpty)

    let containers = EditorPanelPlugin.viewContainers(
        context: LumiPluginContext(
            activeSectionID: "LumiEditor",
            activeSectionTitle: "Editor",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiEditorServicing.self, core)
            }
        )
    )
    #expect(containers.count == 1)
    #expect(containers[0].showsPanelChrome == true)
}

@MainActor
@Test func editorBottomProblemsPanelPluginRequiresPanelChrome() async throws {
    let hidden = LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    let visible = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        showsPanelChrome: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, EditorCore())
        }
    )

    #expect(EditorBottomProblemsPanelPlugin.panelBottomTabItems(context: hidden).isEmpty)
    #expect(EditorBottomProblemsPanelPlugin.panelBottomTabItems(context: visible).count == 1)
}

@MainActor
@Test func editorPanelHeaderPluginsSortByOrder() async throws {
    let context = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        showsPanelChrome: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, EditorCore())
        }
    )

    let plugins: [any LumiPlugin.Type] = [
        EditorTabStripHeaderPlugin.self,
        EditorBreadcrumbHeaderPlugin.self,
    ]
    let items = plugins
        .flatMap { $0.panelHeaderItems(context: context) }
        .sorted { $0.order < $1.order }

    #expect(items.map(\.id) == [
        EditorBreadcrumbHeaderPlugin.info.id,
        EditorTabStripHeaderPlugin.info.id,
    ])
}

@MainActor
@Test func editorRailFileTreePluginContributesExplorerTab() async throws {
    let context = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        showsPanelChrome: true
    )

    let tabs = EditorRailFileTreePanelPlugin.panelRailTabItems(context: context)
    #expect(tabs.map(\.id) == ["explorer"])
}
