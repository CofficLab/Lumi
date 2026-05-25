import AgentToolKit
import LumiCoreKit
import Testing
@testable import PluginWebFetch

@Suite("PluginWebFetch")
struct PluginWebFetchTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(WebFetchPlugin.id == "WebFetch")
        #expect(WebFetchPlugin.displayName == "Web Fetch")
        #expect(WebFetchPlugin.iconName == "globe")
        #expect(WebFetchPlugin.category == .network)
        #expect(WebFetchPlugin.order == 100)
    }

    @MainActor
    @Test("plugin registers one web fetch tool")
    func pluginRegistersTool() {
        let tools = WebFetchPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 1)
        #expect(tools.first?.name == "web_fetch")
    }

    @Test("tool schema requires url")
    func toolSchemaRequiresURL() throws {
        let tool = WebFetchTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["url"])

        let properties = try #require(schema["properties"] as? [String: [String: String]])
        #expect(properties["url"]?["type"] == "string")
    }

    @Test("tool risk level is medium")
    func toolRiskLevel() {
        let tool = WebFetchTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginWebFetchLocalization.bundle.url(forResource: "WebFetch", withExtension: "xcstrings") != nil)
        #expect(PluginWebFetchLocalization.string("Web Fetch").isEmpty == false)
    }
}
