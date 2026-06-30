import Foundation
import LumiCoreKit
import Testing
@testable import ShowImagePlugin

@Suite("PluginShowImage", .serialized)
struct PluginShowImageTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(ShowImagePlugin.id == "ShowImage")
        #expect(ShowImagePlugin.displayName == "Show Image")
        #expect(ShowImagePlugin.iconName == "photo.on.rectangle")
        #expect(ShowImagePlugin.category == .general)
        #expect(ShowImagePlugin.order == 97)
    }

    @MainActor
    @Test("plugin registers one show image tool")
    func pluginRegistersTool() {
        let tools = ShowImagePlugin.agentTools(
            context: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        )

        #expect(tools.count == 1)
        #expect(tools.first?.name == "show_image")
    }

    @Test("tool schema requires source")
    func toolSchemaRequiresSource() throws {
        let tool = ShowImageTool()
        let schema = tool.inputSchema

        guard case .object(let keys) = schema else {
            Issue.record("schema should be an object"); return
        }
        guard case .array(let requiredValues) = keys["required"] else {
            Issue.record("schema should declare required array"); return
        }
        let required = requiredValues.compactMap { if case .string(let s) = $0 { s } else { nil } }
        #expect(required == ["source"])

        guard case .object(let properties) = keys["properties"],
              case .object(let sourceProps) = properties["source"],
              case .string(let sourceType) = sourceProps["type"] else {
            Issue.record("schema should declare source property"); return
        }
        #expect(sourceType == "string")

        guard case .object(let maxWidthProps) = properties["maxWidth"] else {
            Issue.record("schema should declare maxWidth property"); return
        }
        if case .string(let type) = maxWidthProps["type"] {
            #expect(type == "integer")
        } else {
            Issue.record("maxWidth type missing")
        }
        if case .int(let minimum) = maxWidthProps["minimum"] {
            #expect(minimum == ShowImageTool.minMaxWidth)
        } else {
            Issue.record("maxWidth minimum missing")
        }
        if case .int(let maximum) = maxWidthProps["maximum"] {
            #expect(maximum == ShowImageTool.maxMaxWidth)
        } else {
            Issue.record("maxWidth maximum missing")
        }
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = ShowImageTool()

        #expect(tool.riskLevel(arguments: [:], context: nil) == .low)
    }

    @Test("max width is clamped to supported range")
    func maxWidthIsClampedToSupportedRange() {
        #expect(ShowImageTool.normalizedMaxWidth(nil) == ShowImageTool.defaultMaxWidth)
        #expect(ShowImageTool.normalizedMaxWidth(-1) == ShowImageTool.minMaxWidth)
        #expect(ShowImageTool.normalizedMaxWidth(50) == ShowImageTool.minMaxWidth)
        #expect(ShowImageTool.normalizedMaxWidth(320.0) == 320)
        #expect(ShowImageTool.normalizedMaxWidth("640") == 640)
        #expect(ShowImageTool.normalizedMaxWidth(320) == 320)
        #expect(ShowImageTool.normalizedMaxWidth(9_999) == ShowImageTool.maxMaxWidth)
        #expect(ShowImageTool.normalizedMaxWidth("not-a-number") == ShowImageTool.defaultMaxWidth)
    }

    @MainActor
    @Test("tool trims copied remote source whitespace")
    func toolTrimsCopiedRemoteSourceWhitespace() async throws {
        ShowImageState.shared.clear()
        let tool = ShowImageTool()
        let context = LumiToolExecutionContext(conversationID: UUID(), toolCallID: "call_1", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["source": .string(" \nhttps://example.com/image.png\t")],
            context: context
        )

        #expect(result == "Image displayed successfully. Source: https://example.com/image.png")
        #expect(ShowImageState.shared.displayItem?.source == .remote("https://example.com/image.png"))
        ShowImageState.shared.clear()
    }

    @Test("tool resolves URL schemes case-insensitively")
    func toolResolvesURLSchemesCaseInsensitively() throws {
        #expect(try ShowImageTool.normalizedSource(from: " HTTPS://example.com/image.png ") == .remote("HTTPS://example.com/image.png"))
        #expect(try ShowImageTool.normalizedSource(from: "http://example.com/image.png") == .remote("http://example.com/image.png"))
    }

    @Test("tool rejects unsupported URL schemes clearly")
    func toolRejectsUnsupportedURLSchemesClearly() {
        #expect(throws: ShowImageTool.SourceError.unsupportedScheme("ftp")) {
            try ShowImageTool.normalizedSource(from: "ftp://example.com/image.png")
        }
    }

    @MainActor
    @Test("tool accepts uppercase HTTPS remote source")
    func toolAcceptsUppercaseHTTPSRemoteSource() async throws {
        ShowImageState.shared.clear()
        let tool = ShowImageTool()
        let context = LumiToolExecutionContext(conversationID: UUID(), toolCallID: "call_upper_https", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["source": .string("HTTPS://example.com/image.png")],
            context: context
        )

        #expect(result == "Image displayed successfully. Source: HTTPS://example.com/image.png")
        #expect(ShowImageState.shared.displayItem?.source == .remote("HTTPS://example.com/image.png"))
        ShowImageState.shared.clear()
    }

    @MainActor
    @Test("tool reports unsupported remote URL scheme")
    func toolReportsUnsupportedRemoteURLScheme() async throws {
        ShowImageState.shared.clear()
        let tool = ShowImageTool()
        let context = LumiToolExecutionContext(conversationID: UUID(), toolCallID: "call_ftp", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["source": .string("ftp://example.com/image.png")],
            context: context
        )

        #expect(result == "Error: Unsupported image URL scheme 'ftp'. Only HTTP/HTTPS URLs are supported.")
        #expect(ShowImageState.shared.displayItem == nil)
    }

    @MainActor
    @Test("tool clamps displayed remote max width")
    func toolClampsDisplayedRemoteMaxWidth() async throws {
        ShowImageState.shared.clear()
        let tool = ShowImageTool()
        let context = LumiToolExecutionContext(conversationID: UUID(), toolCallID: "call_2", toolName: tool.name)

        _ = try await tool.execute(
            arguments: [
                "source": .string("https://example.com/image.png"),
                "maxWidth": .int(9_999),
            ],
            context: context
        )

        #expect(ShowImageState.shared.displayItem?.maxWidth == ShowImageTool.maxMaxWidth)
        ShowImageState.shared.clear()
    }

    @MainActor
    @Test("tool accepts JSON-style max width values")
    func toolAcceptsJSONStyleMaxWidthValues() async throws {
        ShowImageState.shared.clear()
        let tool = ShowImageTool()
        let context = LumiToolExecutionContext(conversationID: UUID(), toolCallID: "call_3", toolName: tool.name)

        _ = try await tool.execute(
            arguments: [
                "source": .string("https://example.com/image.png"),
                "maxWidth": .double(640.0),
            ],
            context: context
        )

        #expect(ShowImageState.shared.displayItem?.maxWidth == 640)

        _ = try await tool.execute(
            arguments: [
                "source": .string("https://example.com/image.png"),
                "maxWidth": .string("500"),
            ],
            context: context
        )

        #expect(ShowImageState.shared.displayItem?.maxWidth == 500)
        ShowImageState.shared.clear()
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginShowImageLocalization.bundle.url(forResource: "ShowImage", withExtension: "xcstrings") != nil)
        #expect(PluginShowImageLocalization.string("Show Image").isEmpty == false)
    }

    @Test("show image source enum works")
    func showImageSourceEnum() {
        let local = ShowImageSource.local("/path/to/image.png")
        let remote = ShowImageSource.remote("https://example.com/image.png")

        #expect(local.stringValue == "/path/to/image.png")
        #expect(remote.stringValue == "https://example.com/image.png")
        #expect(local.isRemote == false)
        #expect(remote.isRemote == true)
    }
}
