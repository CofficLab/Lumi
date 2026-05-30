import AgentToolKit
import LumiCoreKit
import Testing
@testable import PluginWebSearch

@Suite("PluginWebSearch")
struct PluginWebSearchTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(WebSearchPlugin.id == "WebSearch")
        #expect(WebSearchPlugin.displayName == "Web Search")
        #expect(WebSearchPlugin.iconName == "magnifyingglass")
        #expect(WebSearchPlugin.category == .network)
        #expect(WebSearchPlugin.order == 101)
    }

    @MainActor
    @Test("plugin registers one web search tool")
    func pluginRegistersTool() {
        let tools = WebSearchPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 1)
        #expect(tools.first?.name == "web_search")
    }

    @Test("tool schema requires query")
    func toolSchemaRequiresQuery() throws {
        let tool = WebSearchTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["query"])

        let properties = try #require(schema["properties"] as? [String: [String: String]])
        #expect(properties["query"]?["type"] == "string")
    }

    @Test("tool risk level is low")
    func toolRiskLevel() {
        let tool = WebSearchTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginWebSearchLocalization.bundle.url(forResource: "WebSearch", withExtension: "xcstrings") != nil)
        #expect(PluginWebSearchLocalization.string("Web Search").isEmpty == false)
    }
}
