import AgentToolKit
import Foundation
import Testing
@testable import AppIconDesignerPlugin

@MainActor
@Suite("Icon document tools", .serialized)
struct IconDocumentToolTests {
    @MainActor
    @Test("creates and edits vector icon documents")
    func createsAndEditsVectorIconDocuments() async throws {
        try await withIconToolKernel("create_icon_document") { kernel in
            IconDocumentStore.shared.resetForTests()

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
    }

    @MainActor
    @Test("renders SVG output")
    func rendersSVGOutput() async throws {
        try await withIconToolKernel("create_icon_document") { kernel in
            IconDocumentStore.shared.resetForTests()

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
    }

    @MainActor
    @Test("creates gradient symbol document")
    func createsGradientSymbolDocument() async throws {
        try await withIconToolKernel("create_icon_document") { kernel in
            IconDocumentStore.shared.resetForTests()

            _ = try await CreateIconDocumentTool().execute(
                arguments: [
                    "title": .string("Symbol"),
                ],
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
    }

    @MainActor
    @Test("applies built in icon preset")
    func appliesBuiltInIconPreset() async throws {
        try await withIconToolKernel("apply_icon_preset") { kernel in
            IconDocumentStore.shared.resetForTests()

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
    }

    @MainActor
    @Test("manages layers and history")
    func managesLayersAndHistory() throws {
        IconDocumentStore.shared.resetForTests()

        _ = IconDocumentStore.shared.createDocument(title: "Layers", width: 1024, height: 1024, background: .color("#111827"))
        let first = IconLayer(name: "First", shape: .circle(cx: 512, cy: 512, radius: 240), fill: .color("#ffffff"))
        let second = IconLayer(name: "Second", shape: .symbol(name: "bolt.fill", x: 512, y: 512, size: 320, weight: "bold"), fill: .color("#38bdf8"))

        _ = try IconDocumentStore.shared.addLayer(first)
        _ = try IconDocumentStore.shared.addLayer(second)
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

    @MainActor
    @Test("does not record undo for unchanged edits")
    func doesNotRecordUndoForUnchangedEdits() throws {
        IconDocumentStore.shared.resetForTests()

        _ = IconDocumentStore.shared.createDocument(title: "No Op", width: 1024, height: 1024, background: .color("#111827"))
        #expect(!IconDocumentStore.shared.canUndo)

        _ = try IconDocumentStore.shared.updateSelectedDocument { _ in }

        #expect(!IconDocumentStore.shared.canUndo)
    }

    @MainActor
    @Test("sanitizes unsafe imported documents")
    func sanitizesUnsafeImportedDocuments() throws {
        IconDocumentStore.shared.resetForTests()

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

        let imported = IconDocumentStore.shared.importDocument(unsafe)

        #expect(!imported.id.isEmpty)
        #expect(imported.title == "Untitled Icon")
        #expect(imported.width == 1024)
        #expect(imported.height == IconDocumentSanitizer.minimumCanvasSize)
        #expect(imported.layers.count == 1)
        #expect(imported.layers[0].opacity == 1)
        #expect(imported.layers[0].fill == .color("#00000000"))
        #expect(imported.layers[0].blurRadius == 0)
    }

    @MainActor
    @Test("saves and loads icon document JSON")
    func savesAndLoadsIconDocumentJSON() throws {
        IconDocumentStore.shared.resetForTests()

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

    @MainActor
    @Test("exports SVG file")
    func exportsSVGFile() async throws {
        try await withIconToolKernel("export_icon_svg") { kernel in
            IconDocumentStore.shared.resetForTests()

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
                arguments: [
                    "outputPath": .string(outputURL.path),
                ],
                kernel: kernel
            )

            #expect(result.contains(outputURL.path))
            #expect(FileManager.default.fileExists(atPath: outputURL.path))
        }
    }

    @MainActor
    @Test("updates lints saves and loads document through agent tools")
    func updatesLintsSavesAndLoadsDocumentThroughAgentTools() async throws {
        try await withIconToolKernel("create_icon_document") { kernel in
            IconDocumentStore.shared.resetForTests()

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

            let lintResult = try await LintIconDocumentTool().execute(
                arguments: [:],
                kernel: kernel
            )
            #expect(lintResult.contains("exportable: true"))

            let outputURL = tempRoot.appendingPathComponent("agent-icon.json")
            let saveResult = try await SaveIconDocumentTool().execute(
                arguments: [
                    "outputPath": .string(outputURL.path),
                ],
                kernel: kernel
            )
            #expect(saveResult.contains(outputURL.path))
            #expect(FileManager.default.fileExists(atPath: outputURL.path))

            IconDocumentStore.shared.resetForTests()
            let loadResult = try await LoadIconDocumentTool().execute(
                arguments: [
                    "inputPath": .string(outputURL.path),
                ],
                kernel: kernel
            )

            #expect(loadResult.contains("Agent Icon"))
            #expect(IconDocumentStore.shared.selectedDocument?.title == "Agent Icon")
            #expect(IconDocumentStore.shared.selectedDocument?.layers.count == 1)
        }
    }

    @MainActor
    @Test("localizes schemas")
    func localizesSchemas() {
        IconDocumentStore.shared.resetForTests()

        let schema = CreateIconDocumentTool().inputSchema(for: .chinese)
        let properties = try #require(schema["properties"] as? [String: Any])
        let title = try #require(properties["title"] as? [String: Any])
        #expect((title["description"] as? String)?.contains("文档标题") == true)
    }
}

private func withIconToolKernel<T>(
    _ toolName: String,
    operation: @escaping @Sendable (LumiKernel) async throws -> T
) async throws -> T {
    let kernel = LumiKernel()
    let state = LumiToolExecutionContextState(
        conversationID: UUID(),
        toolCallID: UUID().uuidString,
        toolName: toolName
    )
    return try await kernel.withToolExecutionContextState(state) {
        try await operation(kernel)
    }
}
