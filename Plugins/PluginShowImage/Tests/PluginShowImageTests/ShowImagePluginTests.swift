import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import PluginShowImage

@Suite("PluginShowImage", .serialized)
struct PluginShowImageTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(ShowImagePlugin.id == "ShowImage")
        #expect(ShowImagePlugin.displayName == "Show Image")
        #expect(ShowImagePlugin.iconName == "photo.on.rectangle")
        #expect(ShowImagePlugin.category == .integration)
        #expect(ShowImagePlugin.order == 97)
    }

    @MainActor
    @Test("plugin registers one show image tool")
    func pluginRegistersTool() {
        let tools = ShowImagePlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 1)
        #expect(tools.first?.name == "show_image")
    }

    @Test("tool schema requires source")
    func toolSchemaRequiresSource() throws {
        let tool = ShowImageTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["source"])

        let properties = try #require(schema["properties"] as? [String: [String: Any]])
        #expect(properties["source"]?["type"] as? String == "string")
        #expect(properties["maxWidth"]?["type"] as? String == "integer")
        #expect(properties["maxWidth"]?["minimum"] as? Int == ShowImageTool.minMaxWidth)
        #expect(properties["maxWidth"]?["maximum"] as? Int == ShowImageTool.maxMaxWidth)
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = ShowImageTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
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
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["source": ToolArgument(" \nhttps://example.com/image.png\t")],
            context: context
        )

        #expect(result == "Image displayed successfully. Source: https://example.com/image.png")
        #expect(ShowImageState.shared.displayItem?.source == .remote("https://example.com/image.png"))
        ShowImageState.shared.clear()
    }

    @MainActor
    @Test("tool clamps displayed remote max width")
    func toolClampsDisplayedRemoteMaxWidth() async throws {
        ShowImageState.shared.clear()
        let tool = ShowImageTool()
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_2", toolName: tool.name)

        _ = try await tool.execute(
            arguments: [
                "source": ToolArgument("https://example.com/image.png"),
                "maxWidth": ToolArgument(9_999),
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
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_3", toolName: tool.name)

        _ = try await tool.execute(
            arguments: [
                "source": ToolArgument("https://example.com/image.png"),
                "maxWidth": ToolArgument(640.0),
            ],
            context: context
        )

        #expect(ShowImageState.shared.displayItem?.maxWidth == 640)

        _ = try await tool.execute(
            arguments: [
                "source": ToolArgument("https://example.com/image.png"),
                "maxWidth": ToolArgument("500"),
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
