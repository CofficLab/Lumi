import AgentToolKit
import Foundation
import Testing
@testable import PluginAppIconDesigner

@Suite("Icon document tools", .serialized)
struct IconDocumentToolTests {
    @MainActor
    @Test("creates and edits vector icon documents")
    func createsAndEditsVectorIconDocuments() async throws {
        IconDocumentStore.shared.resetForTests()

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": ToolArgument("Play"),
                "background": ToolArgument("#111827"),
            ],
            context: toolContext("create_icon_document")
        )

        _ = try await AddIconShapeTool().execute(
            arguments: [
                "shape": ToolArgument("circle"),
                "name": ToolArgument("Blue base"),
                "fill": ToolArgument("#38bdf8"),
                "radius": ToolArgument(280),
            ],
            context: toolContext("add_icon_shape")
        )

        let document = try #require(IconDocumentStore.shared.selectedDocument)
        let layer = try #require(document.layers.first)

        _ = try await UpdateIconLayerTool().execute(
            arguments: [
                "layerId": ToolArgument(layer.id),
                "fill": ToolArgument("#ffffff"),
                "translateX": ToolArgument(12),
                "rotationDegrees": ToolArgument(45),
            ],
            context: toolContext("update_icon_layer")
        )

        let updated = try #require(IconDocumentStore.shared.selectedDocument)
        #expect(updated.layers.count == 1)
        #expect(updated.layers[0].fill == .color("#ffffff"))
        #expect(updated.layers[0].transform.translateX == 12)
        #expect(updated.layers[0].transform.rotationDegrees == 45)
    }

    @MainActor
    @Test("renders SVG output")
    func rendersSVGOutput() async throws {
        IconDocumentStore.shared.resetForTests()

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": ToolArgument("Triangle"),
                "background": ToolArgument("#0f172a"),
            ],
            context: toolContext("create_icon_document")
        )

        _ = try await AddIconShapeTool().execute(
            arguments: [
                "shape": ToolArgument("triangle"),
                "fill": ToolArgument("#f8fafc"),
                "x": ToolArgument(300),
                "y": ToolArgument(240),
                "width": ToolArgument(420),
                "height": ToolArgument(520),
            ],
            context: toolContext("add_icon_shape")
        )

        let document = try #require(IconDocumentStore.shared.selectedDocument)
        let svg = IconSVGRenderer().render(document: document)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("#0f172a"))
        #expect(svg.contains("<polygon"))
        #expect(svg.contains("#f8fafc"))
    }

    @MainActor
    @Test("exports SVG file")
    func exportsSVGFile() async throws {
        IconDocumentStore.shared.resetForTests()

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerSVGTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try await CreateIconDocumentTool().execute(
            arguments: [
                "title": ToolArgument("Export Test"),
                "background": ToolArgument("#ffffff"),
            ],
            context: toolContext("create_icon_document")
        )

        let outputURL = tempRoot.appendingPathComponent("icon.svg")
        let result = try await ExportIconSVGTool().execute(
            arguments: [
                "outputPath": ToolArgument(outputURL.path),
            ],
            context: toolContext("export_icon_svg")
        )

        #expect(result.contains(outputURL.path))
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }
}

private func toolContext(_ toolName: String) -> ToolExecutionContext {
    ToolExecutionContext(
        conversationId: UUID(),
        toolCallId: UUID().uuidString,
        toolName: toolName
    )
}
