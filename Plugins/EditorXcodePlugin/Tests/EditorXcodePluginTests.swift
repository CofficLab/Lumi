@testable import EditorXcodePlugin
@testable import EditorService
import LumiCoreKit
import Testing

@Test func editorXcodePluginInfo() {
    #expect(EditorXcodePlugin.info.id == "EditorXcode")
}

@MainActor
@Test func titleToolbarItemsRequireEditorPanel() {
    let hiddenContext = LumiPluginContext(activeSectionID: "Other", activeSectionTitle: "Other")
    #expect(EditorXcodePlugin.titleToolbarItems(context: hiddenContext).isEmpty)

    let visibleWithoutService = LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    #expect(EditorXcodePlugin.titleToolbarItems(context: visibleWithoutService).isEmpty)

    let core = EditorCore()
    let visibleContext = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, core)
        }
    )
    #expect(EditorXcodePlugin.titleToolbarItems(context: visibleContext).count == 1)
}
