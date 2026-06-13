@testable import EditorSwiftPlugin
@testable import EditorService
import LumiCoreKit
import Testing

@Test func editorSwiftPluginInfo() {
    #expect(EditorSwiftPlugin.info.id == "EditorSwift")
    #expect(EditorSwiftPlugin.policy == .alwaysOn)
    #expect(EditorSwiftPlugin.category == .development)
    #expect(EditorSwiftPlugin.iconName == "swift")
}

@MainActor
@Test func editorSwiftEditorPluginMetadata() {
    #expect(EditorSwiftEditorPlugin.id == "EditorSwift")
    #expect(EditorSwiftEditorPlugin.order == 4)
    #expect(EditorSwiftEditorPlugin.shared.providesEditorExtensions)
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
    let items = EditorSwiftPlugin.titleToolbarItems(context: visibleContext)
    #expect(items.count == 1)
    #expect(items[0].id == "EditorSwift.xcode-scheme")
    #expect(items[0].placement == .center)
}

@MainActor
@Test func statusBarItemsRequireEditorPanel() {
    let core = EditorCore()
    let context = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, core)
        }
    )
    let items = EditorSwiftPlugin.statusBarItems(context: context)
    #expect(items.count == 1)
    #expect(items[0].id == "EditorSwift.xcode")
    #expect(items[0].placement == .trailing)
}

@MainActor
@Test func agentToolsExposeSwiftXcodeTools() {
    let tools = EditorSwiftPlugin.agentTools(context: LumiPluginContext(activeSectionID: "main", activeSectionTitle: "Main"))
    #expect(tools.count == 3)
    #expect(tools.map(\.name).sorted() == [
        "add_xcode_package",
        "generate_xcode_project",
        "list_xcode_packages",
    ].sorted())
}

@Test func swiftLanguageDescriptor() {
    let descriptor = EditorSwiftPluginDescriptor.swift
    #expect(descriptor.languageId == "swift")
    #expect(descriptor.fileExtensions == ["swift"])
    #expect(descriptor.lineComment == "//")
}
