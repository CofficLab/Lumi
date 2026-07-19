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
    #expect(EditorSwiftPlugin.titleToolbarItems(lumiCore: hiddenContext).isEmpty)

    let visibleWithoutService = LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    #expect(EditorSwiftPlugin.titleToolbarItems(lumiCore: visibleWithoutService).isEmpty)

    let core = EditorCore()
    let visibleContext = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, core)
        }
    )
    let items = EditorSwiftPlugin.titleToolbarItems(lumiCore: visibleContext)
    #expect(items.count == 1)
    #expect(items[0].id == "EditorSwift.xcode-scheme")
    #expect(items[0].placement == .leading)
}

@MainActor
@Test func panelBottomTabItemsRequireEditorPanel() {
    let hiddenContext = LumiPluginContext(activeSectionID: "Other", activeSectionTitle: "Other", showsPanelChrome: true)
    #expect(EditorSwiftPlugin.panelBottomTabItems(lumiCore: hiddenContext).isEmpty)

    let withoutChrome = LumiPluginContext(activeSectionID: "LumiEditor", activeSectionTitle: "Editor")
    #expect(EditorSwiftPlugin.panelBottomTabItems(lumiCore: withoutChrome).isEmpty)

    let core = EditorCore()
    let visibleContext = LumiPluginContext(
        activeSectionID: "LumiEditor",
        activeSectionTitle: "Editor",
        showsPanelChrome: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiEditorServicing.self, core)
        }
    )
    let tabs = EditorSwiftPlugin.panelBottomTabItems(lumiCore: visibleContext)
    #expect(tabs.count == 1)
    #expect(tabs[0].id == SwiftBuildPanelIDs.bottomTab)
    #expect(tabs[0].systemImage == "play.fill")
}

@MainActor
@Test func agentToolsExposeSwiftXcodeTools() {
    let tools = EditorSwiftPlugin.agentTools(lumiCore: PreviewEditorSwiftSupport.lumiCore)
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
