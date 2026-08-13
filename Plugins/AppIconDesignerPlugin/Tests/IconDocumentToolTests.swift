import Foundation
import KernelLumi
import Testing
@testable import AppIconDesignerPlugin

@MainActor
@Suite("Icon document tools", .serialized)
struct IconDocumentToolTests {

    /// 重置运行时并配置一个临时 app 作用域存储目录，返回该目录（调用方负责清理）。
    @discardableResult
    private func resetWithTempAppStorage() throws -> URL {
        IconDesignerRuntime.reset()
        IconDocumentStore.shared.resetForTests()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppIconDesignerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        IconDesignerRuntime.setAppStorage(root)
        return root
    }

    @Test("creates and edits vector icon documents")
    func createsAndEditsVectorIconDocuments() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": .string("Play"),
                "background": .string("#111827"),
            ],
            kernel: kernel
        )

        _ = try await AddIconShapeTool().execute(
            arguments: [
                "shape": .string("circle"),
                "name": .string("Blue base"),
                "fill": .string("#38bdf8"),
                "radius": .int(280),
            ],
            kernel: kernel
        )

        let document = try #require(IconDocumentStore.shared.selectedDocument)
        let layer = try #require(document.layers.first)

        _ = try await UpdateIconLayerTool().execute(
            arguments: [
                "layerId": .string(layer.id),
                "fill": .string("#ffffff"),
                "translateX": .int(12),
                "rotationDegrees": .int(45),
            ],
            kernel: kernel
        )

        let updated = try #require(IconDocumentStore.shared.selectedDocument)
        #expect(updated.layers.count == 1)
        #expect(updated.layers[0].fill == .color("#ffffff"))
        #expect(updated.layers[0].transform.translateX == 12)
        #expect(updated.layers[0].transform.rotationDegrees == 45)
    }

    @Test("renders SVG output")
    func rendersSVGOutput() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": .string("Triangle"),
                "background": .string("#0f172a"),
            ],
            kernel: kernel
        )

        _ = try await AddIconShapeTool().execute(
            arguments: [
                "shape": .string("triangle"),
                "fill": .string("#f8fafc"),
                "x": .int(300),
                "y": .int(240),
                "width": .int(420),
                "height": .int(520),
            ],
            kernel: kernel
        )

        let document = try #require(IconDocumentStore.shared.selectedDocument)
        let svg = IconSVGRenderer().render(document: document)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("#0f172a"))
        #expect(svg.contains("<polygon"))
        #expect(svg.contains("#f8fafc"))
    }

    @Test("creates gradient symbol document")
    func createsGradientSymbolDocument() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        _ = try await CreateIconDocumentTool().execute(
            arguments: ["title": .string("Symbol")],
            kernel: kernel
        )

        _ = try await SetIconBackgroundTool().execute(
            arguments: [
                "type": .string("linearGradient"),
                "colors": .array([.string("#111827"), .string("#2563eb")]),
            ],
            kernel: kernel
        )

        _ = try await AddIconShapeTool().execute(
            arguments: [
                "shape": .string("symbol"),
                "symbolName": .string("sparkles"),
                "fill": .string("#ffffff"),
                "shadowColor": .string("#00000055"),
                "shadowRadius": .int(32),
            ],
            kernel: kernel
        )

        let document = try #require(IconDocumentStore.shared.selectedDocument)
        #expect(document.background.hexValue == "#111827")
        #expect(document.layers.count == 1)
        #expect(document.layers[0].shadow?.radius == 32)

        if case .symbol(let name, _, _, _, _) = document.layers[0].shape {
            #expect(name == "sparkles")
        } else {
            Issue.record("Expected symbol layer")
        }
    }

    @Test("applies built in icon preset")
    func appliesBuiltInIconPreset() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        let result = try await ApplyIconPresetTool().execute(
            arguments: [
                "presetId": .string("developer-tool"),
                "title": .string("Code Tool"),
            ],
            kernel: kernel
        )

        let document = try #require(IconDocumentStore.shared.selectedDocument)
        #expect(result.contains("developer-tool"))
        #expect(document.title == "Code Tool")
        #expect(document.layers.count == 2)
        #expect(document.background.hexValue == "#18181b")
    }

    @Test("manages layers and history")
    func managesLayersAndHistory() throws {
        try resetWithTempAppStorage()

        let document = IconDocumentStore.shared.createDocument(
            title: "Layers",
            width: 1024,
            height: 1024,
            background: .color("#111827"),
            scope: .app
        )
        let first = IconLayer(name: "First", shape: .circle(cx: 512, cy: 512, radius: 240), fill: .color("#ffffff"))
        let second = IconLayer(name: "Second", shape: .symbol(name: "bolt.fill", x: 512, y: 512, size: 320, weight: "bold"), fill: .color("#38bdf8"))

        _ = try IconDocumentStore.shared.addLayer(first, documentId: document.id, scope: .app)
        _ = try IconDocumentStore.shared.addLayer(second, documentId: document.id, scope: .app)
        #expect(IconDocumentStore.shared.selectedDocument?.layers.map(\.name) == ["First", "Second"])
        #expect(IconDocumentStore.shared.canUndo)

        _ = try IconDocumentStore.shared.moveLayer(id: first.id, direction: .forward)
        #expect(IconDocumentStore.shared.selectedDocument?.layers.map(\.name) == ["Second", "First"])

        let duplicate = try IconDocumentStore.shared.duplicateLayer(id: second.id)
        #expect(duplicate.layer.name == "Second Copy")
        #expect(IconDocumentStore.shared.selectedDocument?.layers.count == 3)

        _ = try IconDocumentStore.shared.deleteLayer(id: duplicate.layer.id)
        #expect(IconDocumentStore.shared.selectedDocument?.layers.count == 2)

        IconDocumentStore.shared.undo()
        #expect(IconDocumentStore.shared.selectedDocument?.layers.count == 3)

        IconDocumentStore.shared.redo()
        #expect(IconDocumentStore.shared.selectedDocument?.layers.count == 2)
    }

    @Test("does not record undo for unchanged edits")
    func doesNotRecordUndoForUnchangedEdits() throws {
        try resetWithTempAppStorage()

        _ = IconDocumentStore.shared.createDocument(title: "No Op", width: 1024, height: 1024, background: .color("#111827"), scope: .app)
        #expect(!IconDocumentStore.shared.canUndo)

        _ = try IconDocumentStore.shared.updateSelectedDocument { _ in }

        #expect(!IconDocumentStore.shared.canUndo)
    }

    @Test("sanitizes unsafe imported documents")
    func sanitizesUnsafeImportedDocuments() throws {
        try resetWithTempAppStorage()

        let unsafe = IconDocument(
            id: "",
            title: "   ",
            width: .infinity,
            height: -10,
            background: .linearGradient(colors: ["not-a-color"], startPoint: IconUnitPoint(x: -1, y: 2), endPoint: IconUnitPoint(x: .nan, y: .infinity)),
            layers: [
                IconLayer(
                    id: "",
                    name: "",
                    shape: .rectangle(x: .nan, y: .infinity, width: -20, height: 0, cornerRadius: 9999),
                    fill: .color("bad"),
                    stroke: IconStroke(color: "nope", width: .infinity),
                    opacity: 4,
                    transform: IconTransform(translateX: .infinity, translateY: .nan, scale: -3, rotationDegrees: .infinity),
                    shadow: IconShadow(color: "bad", radius: .infinity, x: .nan, y: .infinity),
                    blurRadius: .infinity
                )
            ]
        )

        let imported = IconDocumentStore.shared.importDocument(unsafe, scope: .app)

        #expect(!imported.id.isEmpty)
        #expect(imported.title == "Untitled Icon")
        #expect(imported.width == 1024)
        #expect(imported.height == IconDocumentSanitizer.minimumCanvasSize)
        #expect(imported.layers.count == 1)
        #expect(imported.layers[0].opacity == 1)
        #expect(imported.layers[0].fill == .color("#00000000"))
        #expect(imported.layers[0].blurRadius == 0)
    }

    @Test("saves and loads icon document JSON")
    func savesAndLoadsIconDocumentJSON() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerDocumentJSONTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let document = IconPresetLibrary.gradientSymbol.makeDocument("Saved Icon")
        let outputURL = tempRoot.appendingPathComponent("icon.json")

        let service = IconDocumentFileService()
        try service.save(document: document, to: outputURL)
        let loaded = try service.load(from: outputURL)

        #expect(loaded.title == "Saved Icon")
        #expect(loaded.layers.count == document.layers.count)
        #expect(loaded.background == document.background)
    }

    @Test("loads legacy document JSON without schema version")
    func loadsLegacyDocumentJSONWithoutSchemaVersion() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerLegacyJSONTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let inputURL = tempRoot.appendingPathComponent("legacy.json")
        let json = """
        {
          "id": "legacy-id",
          "title": "Legacy Icon",
          "width": 1024,
          "height": 1024,
          "background": { "color": { "_0": "#111827" } },
          "layers": [],
          "createdAt": "2026-05-28T00:00:00Z",
          "updatedAt": "2026-05-28T00:00:00Z"
        }
        """
        try json.write(to: inputURL, atomically: true, encoding: .utf8)

        let loaded = try IconDocumentFileService().load(from: inputURL)

        #expect(loaded.schemaVersion == IconDocument.currentSchemaVersion)
        #expect(loaded.title == "Legacy Icon")
        #expect(loaded.id == "legacy-id")
    }

    @Test("exports SVG file")
    func exportsSVGFile() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerSVGTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": .string("Export Test"),
                "background": .string("#ffffff"),
            ],
            kernel: kernel
        )

        let outputURL = tempRoot.appendingPathComponent("icon.svg")
        let result = try await ExportIconSVGTool().execute(
            arguments: ["outputPath": .string(outputURL.path)],
            kernel: kernel
        )

        #expect(result.contains(outputURL.path))
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    @Test("updates lints saves and loads document through agent tools")
    func updatesLintsSavesAndLoadsDocumentThroughAgentTools() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerAgentDocumentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": .string("Agent Icon"),
                "background": .string("#111827"),
            ],
            kernel: kernel
        )

        _ = try await AddIconShapeTool().execute(
            arguments: [
                "shape": .string("rectangle"),
                "fill": .string("#ffffff"),
            ],
            kernel: kernel
        )

        let layer = try #require(IconDocumentStore.shared.selectedDocument?.layers.first)
        _ = try await UpdateIconShapeTool().execute(
            arguments: [
                "layerId": .string(layer.id),
                "x": .int(128),
                "y": .int(128),
                "width": .int(768),
                "height": .int(768),
                "cornerRadius": .int(180),
            ],
            kernel: kernel
        )

        let updated = try #require(IconDocumentStore.shared.selectedDocument?.layers.first)
        if case .rectangle(let x, let y, let width, let height, let cornerRadius) = updated.shape {
            #expect(x == 128)
            #expect(y == 128)
            #expect(width == 768)
            #expect(height == 768)
            #expect(cornerRadius == 180)
        } else {
            Issue.record("Expected rectangle layer")
        }

        let lintResult = try await LintIconDocumentTool().execute(arguments: [:], kernel: kernel)
        #expect(lintResult.contains("exportable: true"))

        let outputURL = tempRoot.appendingPathComponent("agent-icon.json")
        let saveResult = try await SaveIconDocumentTool().execute(
            arguments: ["outputPath": .string(outputURL.path)],
            kernel: kernel
        )
        #expect(saveResult.contains(outputURL.path))
        #expect(FileManager.default.fileExists(atPath: outputURL.path))

        // 清空内存中文档（保留已配置的存储目录），模拟「重新载入」场景。
        IconDocumentStore.shared.reload()
        let loadResult = try await LoadIconDocumentTool().execute(
            arguments: ["inputPath": .string(outputURL.path)],
            kernel: kernel
        )

        #expect(loadResult.contains("Agent Icon"))
        #expect(IconDocumentStore.shared.selectedDocument?.title == "Agent Icon")
        #expect(IconDocumentStore.shared.selectedDocument?.layers.count == 1)
    }

    // MARK: - 双作用域存储

    @Test("explicit scope routes documents to isolated storage")
    func explicitScopeRoutesDocumentsToIsolatedStorage() async throws {
        IconDesignerRuntime.reset()
        IconDocumentStore.shared.resetForTests()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent("icon-app-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = FileManager.default.temporaryDirectory.appendingPathComponent("icon-project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: appRoot)
            try? FileManager.default.removeItem(at: projectRoot)
        }
        let kernel = KernelLumi()
        IconDesignerRuntime.setAppStorage(appRoot)
        IconDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        // 显式 app scope。
        let appCreate = try await CreateIconDocumentTool().execute(
            arguments: ["title": .string("App Icon"), "scope": .string("app")],
            kernel: kernel
        )
        #expect(appCreate.contains("scope=app"))

        // 显式 project scope。
        let projectCreate = try await CreateIconDocumentTool().execute(
            arguments: ["title": .string("Project Icon"), "scope": .string("project")],
            kernel: kernel
        )
        #expect(projectCreate.contains("scope=project"))

        // 文件系统隔离：两个 scope 各自存储。
        #expect(IconDocumentStore.shared.appDocuments.contains(where: { $0.title == "App Icon" }))
        #expect(IconDocumentStore.shared.projectDocuments.contains(where: { $0.title == "Project Icon" }))
        #expect(!IconDocumentStore.shared.appDocuments.contains(where: { $0.title == "Project Icon" }))
        #expect(!IconDocumentStore.shared.projectDocuments.contains(where: { $0.title == "App Icon" }))

        // list 跨作用域枚举并打标。
        let listAll = try await ListIconDocumentsTool().execute(arguments: [:], kernel: kernel)
        #expect(listAll.contains("scope=app"))
        #expect(listAll.contains("scope=project"))
        #expect(listAll.contains("App Icon"))
        #expect(listAll.contains("Project Icon"))

        // 仅 app。
        let listApp = try await ListIconDocumentsTool().execute(arguments: ["scope": .string("app")], kernel: kernel)
        #expect(listApp.contains("App Icon"))
        #expect(!listApp.contains("Project Icon"))
    }

    @Test("scope falls back to app when project missing")
    func scopeFallsBackToAppWhenProjectMissing() async throws {
        IconDesignerRuntime.reset()
        IconDocumentStore.shared.resetForTests()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent("icon-fallback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appRoot) }
        let kernel = KernelLumi()
        IconDesignerRuntime.setAppStorage(appRoot)
        // 不设置 project，模拟无打开项目。

        let create = try await CreateIconDocumentTool().execute(
            arguments: ["title": .string("Default Fallback")],
            kernel: kernel
        )
        #expect(create.contains("scope=app"))
        #expect(IconDocumentStore.shared.appDocuments.contains(where: { $0.title == "Default Fallback" }))
    }

    // MARK: - Review

    @Test("review returns a friendly message when no provider is registered")
    func reviewWithoutProvider() async throws {
        let root = try resetWithTempAppStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()

        _ = try await CreateIconDocumentTool().execute(
            arguments: ["title": .string("Review Me"), "background": .string("#111827")],
            kernel: kernel
        )

        let result = try await ReviewIconTool().execute(arguments: [:], kernel: kernel)
        #expect(result.lowercased().contains("provider") || result.lowercased().contains("评审") || result.lowercased().contains("review"))
    }

    // MARK: - Schema

    @Test("input schema advertises scope and documentId")
    func inputSchemaAdvertisesScopeAndDocumentId() {
        let schema = CreateIconDocumentTool().inputSchema
        guard case .object(let top) = schema,
              case .object(let properties) = top["properties"] ?? .null
        else {
            Issue.record("Unexpected inputSchema shape")
            return
        }
        // create 工具包含 scope（不含 documentId，因为是新建）。
        #expect(properties["scope"] != nil)

        // 编辑工具同时包含 scope 与 documentId。
        let editSchema = SetIconBackgroundTool().inputSchema
        guard case .object(let editTop) = editSchema,
              case .object(let editProperties) = editTop["properties"] ?? .null
        else {
            Issue.record("Unexpected edit inputSchema shape")
            return
        }
        #expect(editProperties["scope"] != nil)
        #expect(editProperties["documentId"] != nil)
    }
}
