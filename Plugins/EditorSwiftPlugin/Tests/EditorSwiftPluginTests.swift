@testable import EditorSwiftPlugin
@testable import EditorService
import LumiCoreKit
import Testing

@Test func editorSwiftPluginInfo() {
    #expect(EditorSwiftPlugin.info.id == "EditorSwift")
}

@MainActor
@Test func titleToolbarItemsRequireEditorPanel() {
    let hiddenContext = LumiPluginContext(activeSectionID: "Other", activeSectionTitle: "Other")
    #expect(EditorSwiftPlugin.titleToolbarItems(context: hiddenContext).isEmpty)

    let visibleWithoutService = LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    #expect(EditorSwiftPlugin.titleToolbarItems(context: visibleWithoutService).isEmpty)

    let core = EditorCore()
    let visibleContext = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, core)
        }
    )
    #expect(EditorSwiftPlugin.titleToolbarItems(context: visibleContext).count == 1)
}
