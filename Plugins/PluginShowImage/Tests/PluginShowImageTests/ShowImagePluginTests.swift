import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import PluginShowImage

@Suite("PluginShowImage")
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

        let properties = try #require(schema["properties"] as? [String: [String: String]])
        #expect(properties["source"]?["type"] == "string")
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = ShowImageTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
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
