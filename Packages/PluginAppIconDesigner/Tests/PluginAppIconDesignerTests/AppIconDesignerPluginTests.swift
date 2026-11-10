import AppKit
import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
import ProviderPromptSuggestion
import Testing
@testable import PluginAppIconDesigner

@Suite("PluginAppIconDesigner", .serialized)
@MainActor
struct AppIconDesignerPluginTests {
    final class TestStorage: StorageProviding {
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
        let rootView = DefaultRootViewProviding()
        let toolbar = DefaultToolbarProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any StorageProviding).self, storage)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        try kernel.start(plugins: [AppIconDesignerPlugin()])
        try await kernel.enablePlugin(id: AppIconDesignerPlugin().id)

        #expect(activity.items.map(\.id) == ["com.coffic.lumi.plugin.app-icon-designer.entry"])
        #expect(rail.tabs.map(\.id) == [AppIconDesignerPlugin.railTabID])
        #expect(rail.activeTabID == AppIconDesignerPlugin.railTabID)
        #expect(chat.isVisible)
        #expect(chat.isContextActive)
        #expect(rootView.isContentHeaderViewHidden)
        #expect(rootView.isRailViewVisible == false)
        #expect(toolbar.visibleCategories == [.global, .project, .chat, .design])

        try kernel.stop()

        #expect(activity.items.isEmpty)
        #expect(rail.tabs.isEmpty)
        #expect(rootView.isContentHeaderViewHidden == false)
        #expect(rootView.isRailViewVisible)
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

    @Test("提示词标题本地化 key 可解析")
    func promptSuggestionLocalizationResolves() {
        let key = "Prompt.Suggestion.Design"
        #expect(AppIconDesignerLocalization.string(key) != key)
    }

    @Test("图标文档在项目作用域创建并落盘")
    func createsAndPersistsProjectDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconDocumentStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        IconDocumentStore.shared.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)
        let document = IconDocumentStore.shared.createDocument(
            title: "Kernel Icon",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )

        #expect(IconDocumentStore.shared.selectedDocumentId == document.id)
        #expect(FileManager.default.fileExists(
            atPath: directory
                .appendingPathComponent("\(document.fileSafeName)-\(document.id.prefix(8)).json")
                .path
        ))

        IconDesignerRuntime.reset()
    }

    @Test("加入项目不预建存储目录，真正写入时才创建")
    func doesNotCreateStorageDirectoryUntilWrite() throws {
        IconDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconLazyDir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            IconDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: projectRoot)
        }

        let storage = projectRoot
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(IconDesignerRuntime.projectFolderName, isDirectory: true)

        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: projectRoot.path)

        // 仅打开项目不应留下空目录。
        #expect(!FileManager.default.fileExists(atPath: storage.path))
        #expect(IconDocumentStore.shared.projectDocuments.isEmpty)

        // 真正写入数据时才创建目录。
        _ = IconDocumentStore.shared.createDocument(
            title: "Lazy Icon",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )
        #expect(FileManager.default.fileExists(atPath: storage.path))
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

        IconDocumentStore.shared.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)

        let tool = CreateIconDocumentTool()
        let arguments: [String: ToolArgument] = [
            "scope": ToolArgument(IconScope.project.rawValue),
            "title": ToolArgument("Agent Icon"),
            "width": ToolArgument(512.0),
            "height": ToolArgument(512.0),
        ]
        let result = try await tool.execute(arguments: arguments)

        #expect(result.contains("Agent Icon"))
        #expect(IconDocumentStore.shared.projectDocuments.contains { $0.title == "Agent Icon" })

        IconDesignerRuntime.reset()
    }

    @Test("没有项目存储时 create_icon_document 在改状态前失败")
    func createIconDocumentFailsWithoutProjectStorage() async throws {
        IconDesignerRuntime.reset()
        defer { IconDesignerRuntime.reset() }

        let tool = CreateIconDocumentTool()
        let arguments: [String: ToolArgument] = [
            "scope": ToolArgument(IconScope.project.rawValue),
            "title": ToolArgument("No Project Icon"),
        ]

        await #expect(throws: IconDocumentStoreError.invalidStorageScope) {
            _ = try await tool.execute(arguments: arguments)
        }
        #expect(IconDocumentStore.shared.projectDocuments.isEmpty, "失败时不得留下内存中的文档")
    }

    @Test("没有项目存储时 apply_icon_preset 在改状态前失败")
    func applyIconPresetFailsWithoutProjectStorage() async throws {
        IconDesignerRuntime.reset()
        defer { IconDesignerRuntime.reset() }

        let preset = try #require(IconPresetLibrary.all.first)
        let tool = ApplyIconPresetTool()
        let arguments: [String: ToolArgument] = ["presetId": ToolArgument(preset.id)]

        await #expect(throws: IconDocumentStoreError.invalidStorageScope) {
            _ = try await tool.execute(arguments: arguments)
        }
        #expect(IconDocumentStore.shared.projectDocuments.isEmpty, "失败时不得留下内存中的文档")
    }

    /// 回归：缺参曾经返回 "错误：缺少必填参数..." / "Error: Missing required..." 字符串，
    /// 默认 `executeResult` 会把它当成成功结果。
    @Test("缺少必填参数时抛出而不是返回本地化错误字符串")
    func missingParameterThrows() async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await ApplyIconPresetTool().executeResult(arguments: [:])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await ExportAppIconTool().executeResult(arguments: [:])
        }
    }

    @Test("未知预设抛出而不是返回错误字符串")
    func unknownPresetThrows() async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await ApplyIconPresetTool().executeResult(
                arguments: ["presetId": ToolArgument("not-a-preset")]
            )
        }
    }

    @Test("preview_icon 工具返回带 PNG 图片附件的结构化结果")
    func executePreviewIconToolReturnsImage() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconToolPreviewTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        IconDocumentStore.shared.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)
        let document = IconDocumentStore.shared.createDocument(
            title: "Preview Icon",
            width: 256,
            height: 256,
            background: .color("#ff0000"),
            scope: .project
        )

        let tool = PreviewIconTool()
        let arguments: [String: ToolArgument] = [
            "scope": ToolArgument(IconScope.project.rawValue),
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

    @Test("replaceSelected 用不同 ID 的 JSON 替换当前选中文档")
    func loadIconDocumentReplacesSelectedDocumentWithDifferentId() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconToolReplaceTests-\(UUID().uuidString)")
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconReplaceSource-\(UUID().uuidString).json")
        defer {
            IconDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: sourceURL)
        }

        IconDocumentStore.shared.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)
        let original = IconDocumentStore.shared.createDocument(
            title: "Original A",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )
        let incoming = IconDocument(id: UUID().uuidString, title: "Incoming B", width: 512, height: 512)
        try IconDocumentFileService().save(document: incoming, to: sourceURL)

        let result = try await LoadIconDocumentTool().execute(arguments: [
            "inputPath": ToolArgument(sourceURL.path),
            "replaceSelected": ToolArgument(true),
        ])

        // 选中文档被 B 的内容替换，ID 保持不变，列表里仍只有一条。
        #expect(IconDocumentStore.shared.projectDocuments.count == 1)
        #expect(IconDocumentStore.shared.selectedDocumentId == original.id)
        let replaced = try #require(IconDocumentStore.shared.projectDocuments.first)
        #expect(replaced.id == original.id)
        #expect(replaced.title == "Incoming B")
        #expect(replaced.width == 512)
        #expect(result.contains(original.id))

        // 旧文件名随标题变化清理，重载磁盘不出现重复文档。
        let reloaded = IconDocumentFileStore.loadAll(storagePath: directory.path)
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.id == original.id)
        #expect(reloaded.first?.title == "Incoming B")
    }

    @Test("未要求替换时 load_icon_document 导入为新副本")
    func loadIconDocumentImportsCopyWhenReplaceSelectedIsFalse() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconToolImportTests-\(UUID().uuidString)")
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconImportSource-\(UUID().uuidString).json")
        defer {
            IconDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: sourceURL)
        }

        IconDocumentStore.shared.setProjectStorage(projectPath: directory.path, projectStorageDirectory: directory)
        let original = IconDocumentStore.shared.createDocument(
            title: "Original A",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )
        let incoming = IconDocument(id: UUID().uuidString, title: "Incoming B", width: 512, height: 512)
        try IconDocumentFileService().save(document: incoming, to: sourceURL)

        _ = try await LoadIconDocumentTool().execute(arguments: [
            "inputPath": ToolArgument(sourceURL.path),
            "replaceSelected": ToolArgument(false),
        ])

        // 原文档保留，新副本拥有自己的 ID 并被选中。
        #expect(IconDocumentStore.shared.projectDocuments.count == 2)
        let imported = try #require(IconDocumentStore.shared.selectedDocument)
        #expect(imported.id != original.id)
        #expect(imported.title == "Incoming B")
    }

    @Test("径向背景半径随导出尺寸缩放")
    func radialBackgroundScalesWithRenderSize() throws {
        let document = IconDocument(
            title: "Radial Background",
            width: 1024,
            height: 1024,
            background: .radialGradient(
                colors: ["#FF0000", "#0000FF"],
                center: .center,
                startRadius: 0,
                endRadius: 512
            )
        )
        let service = AppIconExportService()
        let largePNG = try service.renderPreviewPNG(document: document, pixelSize: 1024)
        let smallPNG = try service.renderPreviewPNG(document: document, pixelSize: 64)

        // 小尺寸中心仍是起始色，角落应已到达渐变末端（半径已缩放为 32）。
        let smallCenter = try pixelColor(in: smallPNG, x: 32, y: 32)
        let smallCorner = try pixelColor(in: smallPNG, x: 2, y: 2)
        let largeCorner = try pixelColor(in: largePNG, x: 2, y: 2)

        #expect(smallCenter.redComponent > 0.8)
        #expect(smallCorner.blueComponent > 0.8, "16–64px 槽位也应显示完整渐变，而不是停在第一种颜色")
        #expect(largeCorner.blueComponent > 0.8)
    }

    @Test("SVG 导出保留渐变、阴影与模糊，不丢失视觉效果")
    func svgExportPreservesGradientsShadowAndBlur() async throws {
        let document = IconDocument(
            title: "Effects",
            width: 1024,
            height: 1024,
            background: .linearGradient(
                colors: ["#111827", "#2563eb", "#38bdf8"],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            layers: [
                IconLayer(
                    name: "Glow",
                    shape: .circle(cx: 512, cy: 512, radius: 330),
                    fill: .radialGradient(
                        colors: ["#ffffff55", "#ffffff00"],
                        center: .center,
                        startRadius: 0,
                        endRadius: 330
                    ),
                    opacity: 0.72,
                    blurRadius: 8
                ),
                IconLayer(
                    name: "Card",
                    shape: .rectangle(x: 200, y: 200, width: 624, height: 624, cornerRadius: 120),
                    fill: .color("#ffffff"),
                    shadow: IconShadow(color: "#00000055", radius: 32, x: 0, y: 20)
                ),
            ]
        )

        let svg = try await IconSVGRenderer().render(document: document)

        #expect(svg.contains("<linearGradient"))
        #expect(svg.contains("<radialGradient"))
        #expect(svg.contains("fill=\"url(#linear-gradient-"))
        #expect(svg.contains("fill=\"url(#radial-gradient-"))
        // 渐变保留全部色标，而不是降为第一种颜色。
        #expect(svg.contains("stop-color=\"#111827\""))
        #expect(svg.contains("stop-color=\"#38BDF8\""))
        #expect(svg.contains("stop-opacity=\""))
        // 阴影与模糊输出为真实滤镜，而不是被忽略。
        #expect(svg.contains("<filter"))
        #expect(svg.contains("feGaussianBlur"))
        #expect(svg.contains("feFlood"))
    }

    @Test("SVG 导出不得把 SF Symbol 输出为字面名称")
    func svgExportRasterizesSymbolsInsteadOfLiteralNames() async throws {
        let document = IconDocument(
            title: "Symbol",
            width: 1024,
            height: 1024,
            background: .color("#f8fafc"),
            layers: [
                IconLayer(
                    name: "Glyph",
                    shape: .symbol(name: "sparkles", x: 512, y: 512, size: 420, weight: "semibold"),
                    fill: .color("#0f172a"),
                    shadow: IconShadow(color: "#00000055", radius: 20, x: 0, y: 12)
                ),
            ]
        )

        let svg = try await IconSVGRenderer().render(document: document)

        #expect(!svg.contains("<text"))
        #expect(!svg.contains(">sparkles<"))
        #expect(svg.contains("<image"))
        #expect(svg.contains("data:image/png;base64,"))
        #expect(svg.contains("width=\"420\""))
        // 阴影同样作用于光栅化后的符号。
        #expect(svg.contains("<filter"))
    }

    private func pixelColor(in pngData: Data, x: Int, y: Int) throws -> NSColor {
        let bitmap = try #require(NSBitmapImageRep(data: pngData))
        return try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
    }
}
