import AgentToolKit
import Foundation
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

    @Test("tool trims copied query whitespace")
    func toolTrimsCopiedQueryWhitespace() async throws {
        let tool = WebSearchTool()
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["query": ToolArgument(" \nLumi release notes\t")],
            context: context
        )

        #expect(result.contains("**Query**: Lumi release notes"))
        #expect(result.contains("https://www.google.com/search?q=Lumi%20release%20notes"))
    }

    @Test("tool rejects blank copied query")
    func toolRejectsBlankCopiedQuery() async throws {
        let tool = WebSearchTool()
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["query": ToolArgument(" \n\t ")],
            context: context
        )

        #expect(result == "Error: Missing required 'query' parameter")
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginWebSearchLocalization.bundle.url(forResource: "WebSearch", withExtension: "xcstrings") != nil)
        #expect(PluginWebSearchLocalization.string("Web Search").isEmpty == false)
    }
}
