import KitAgentTool
import Testing
@testable import PluginWebFetch

@Suite("PluginWebFetch")
@MainActor
struct PluginWebFetchTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(WebFetchPlugin().id == "WebFetch")
        #expect(WebFetchPlugin().name.isEmpty == false)
        #expect(WebFetchPlugin().metadata.category == .integration)
        #expect(WebFetchPlugin().order == 100)
        #expect(WebFetchPlugin().metadata.policy == .enabledByDefault)
    }

    @Test("plugin registers one web fetch tool")
    func pluginRegistersTool() {
        #expect(WebFetchPlugin.agentTools.count == 1)
        #expect(WebFetchPlugin.agentTools.first?.name == "web_fetch")
    }

    @Test("tool schema requires url")
    func toolSchemaRequiresURL() throws {
        let tool = WebFetchTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["url"])

        let properties = try #require(schema["properties"] as? [String: Any])
        #expect((properties["url"] as? [String: String])?["type"] == "string")
    }

    @Test("tool risk level is medium")
    func toolRiskLevel() {
        let tool = WebFetchTool()
        #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
    }

    @Test("tool rejects missing url")
    func toolRejectsMissingURL() async throws {
        let tool = WebFetchTool()
        let result = try await tool.execute(arguments: [:])
        #expect(result == "Error: Missing required 'url' parameter")
    }
}
