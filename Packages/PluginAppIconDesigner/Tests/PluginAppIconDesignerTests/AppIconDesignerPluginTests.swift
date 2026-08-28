import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderStorage
import ProviderToolManager
import ProviderPromptSuggestion
import Testing
@testable import PluginAppIconDesigner

@Suite("PluginAppIconDesigner", .serialized)
@MainActor
struct AppIconDesignerPluginTests {
    private final class TestStorage: StorageProviding {
        let dataRootDirectory: URL

        init() {
            dataRootDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginAppIconDesignerTests-\(UUID().uuidString)")
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        }
    }

    @Test("启动后注册 ActivityBar 与 Rail，并在激活时联动")
    func registersAndActivatesContributions() async throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding()
        let chat = DefaultChatSectionProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any StorageProviding).self, storage)

        try kernel.start(plugins: [AppIconDesignerPlugin()])
        try await kernel.enablePlugin(id: AppIconDesignerPlugin().id)

        #expect(activity.items.map(\.id) == ["com.coffic.lumi.plugin.app-icon-designer.entry"])
        #expect(rail.tabs.map(\.id) == [AppIconDesignerPlugin.railTabID])
        #expect(rail.activeTabID == AppIconDesignerPlugin.railTabID)
        #expect(chat.isVisible)
        #expect(chat.isContextActive)

        try kernel.stop()

        #expect(activity.items.isEmpty)
        #expect(rail.tabs.isEmpty)
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }

    @Test("禁用时仍注册提示词，并标记为需要启用")
    func registersPromptSuggestionWhileDisabled() async throws {
        let kernel = KernelCoreContainer()
        let suggestions = DefaultPromptSuggestionProvider()
        try kernel.registerProvider((any PromptSuggestionProviding).self, suggestions)

        try kernel.start(plugins: [AppIconDesignerPlugin()])

        let suggestion = suggestions.allSuggestions.first
        #expect(suggestion?.pluginID == AppIconDesignerPlugin().id)
        #expect(suggestion?.requiresEnable == true)
        #expect(!kernel.isPluginEnabled(id: AppIconDesignerPlugin().id))

        try await kernel.enablePlugin(id: AppIconDesignerPlugin().id)
        #expect(suggestions.allSuggestions.first?.requiresEnable == false)

        try await kernel.disablePlugin(id: AppIconDesignerPlugin().id)
        #expect(suggestions.allSuggestions.first?.requiresEnable == true)
    }

    @Test("图标文档在 APP 作用域创建并落盘")
    func createsAndPersistsAppDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconDocumentStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        IconDocumentStore.shared.setAppStorage(appStorageDirectory: directory)
        let document = IconDocumentStore.shared.createDocument(
            title: "Kernel Icon",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .app
        )

        #expect(IconDocumentStore.shared.selectedDocumentId == document.id)
        #expect(FileManager.default.fileExists(
            atPath: directory
                .appendingPathComponent("\(document.fileSafeName)-\(document.id.prefix(8)).json")
                .path
        ))

        IconDesignerRuntime.reset()
    }

    @Test("启动后 15 个 Agent 工具注册到 ToolManagerProviding，停止后移除")
    func registersAndRemovesAgentTools() async throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, DefaultRailViewProviding())
        try kernel.registerProvider((any StorageProviding).self, storage)

        try kernel.start(plugins: [AppIconDesignerPlugin()])
        try await kernel.enablePlugin(id: AppIconDesignerPlugin().id)

        // 15 个工具全部注册，且归入本插件分组。
        #expect(toolManager.allTools().count == 15)
        let groups = toolManager.toolsGroupedByPlugin()
        #expect(groups.count == 1)
        #expect(groups.first?.pluginID == "com.coffic.lumi.plugin.app-icon-designer")
        #expect(groups.first?.tools.count == 15)

        let expectedNames: Set<String> = [
            "list_icon_documents", "create_icon_document", "apply_icon_preset",
            "load_icon_document", "save_icon_document", "set_icon_background",
            "add_icon_shape", "update_icon_shape", "update_icon_layer",
            "lint_icon_document", "preview_icon", "export_icon_svg",
            "export_app_icon", "register_app_icon_artifact", "review_icon",
        ]
        #expect(Set(toolManager.allTools().map(\.name)) == expectedNames)

        try kernel.stop()

        #expect(toolManager.allTools().isEmpty)
        #expect(toolManager.toolsGroupedByPlugin().isEmpty)
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }

    @Test("create_icon_document 工具可执行并创建文档")
    func executeCreateIconDocumentTool() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconToolCreateTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        IconDocumentStore.shared.setAppStorage(appStorageDirectory: directory)

        let tool = CreateIconDocumentTool()
        let arguments: [String: ToolArgument] = [
            "scope": ToolArgument(IconScope.app.rawValue),
            "title": ToolArgument("Agent Icon"),
            "width": ToolArgument(512.0),
            "height": ToolArgument(512.0),
        ]
        let result = try await tool.execute(arguments: arguments)

        #expect(result.contains("Agent Icon"))
        #expect(IconDocumentStore.shared.appDocuments.contains { $0.title == "Agent Icon" })

        IconDesignerRuntime.reset()
    }

    @Test("preview_icon 工具返回带 PNG 图片附件的结构化结果")
    func executePreviewIconToolReturnsImage() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconToolPreviewTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        IconDocumentStore.shared.setAppStorage(appStorageDirectory: directory)
        let document = IconDocumentStore.shared.createDocument(
            title: "Preview Icon",
            width: 256,
            height: 256,
            background: .color("#ff0000"),
            scope: .app
        )

        let tool = PreviewIconTool()
        let arguments: [String: ToolArgument] = [
            "scope": ToolArgument(IconScope.app.rawValue),
            "documentId": ToolArgument(document.id),
            "pixelSize": ToolArgument(128.0),
        ]
        let result = try await tool.executeResult(arguments: arguments)

        #expect(!result.isError)
        #expect(!result.images.isEmpty)
        #expect(result.images.first?.mimeType == "image/png")
        #expect(result.images.first?.fileName == "\(document.fileSafeName)-preview.png")

        IconDesignerRuntime.reset()
    }
}
