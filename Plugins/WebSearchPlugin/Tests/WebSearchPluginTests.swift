import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import WebSearchPlugin

@Suite("PluginWebSearch")
struct PluginWebSearchTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(WebSearchPlugin.id == "WebSearch")
        #expect(WebSearchPlugin.displayName == "Web Search")
        #expect(WebSearchPlugin.iconName == "magnifyingglass")
        #expect(WebSearchPlugin.category == .general)
        #expect(WebSearchPlugin.order == 101)
        #expect(WebSearchPlugin.policy == .optIn)
    }

    @MainActor
    @Test("plugin registers one web search tool")
    func pluginRegistersTool() {
        let tools = WebSearchPlugin.agentTools(
            lumiCore: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        )

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
        let tool = WebSearchTool { query in
            #expect(query == "Lumi release notes")
            return [
                WebSearchResult(
                    title: "Lumi Releases",
                    url: "https://example.com/lumi/releases",
                    snippet: "Latest Lumi release notes."
                )
            ]
        }
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["query": ToolArgument(" \nLumi release notes\t")],
            context: context
        )

        #expect(result.contains("**Query**: Lumi release notes"))
        #expect(result.contains("[Lumi Releases](https://example.com/lumi/releases)"))
        #expect(result.contains("Latest Lumi release notes."))
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

    @Test("tool reports empty search result")
    func toolReportsEmptySearchResult() async throws {
        let tool = WebSearchTool { _ in [] }
        let context = ToolExecutionContext(conversationId: UUID(), toolCallId: "call_1", toolName: tool.name)

        let result = try await tool.execute(
            arguments: ["query": ToolArgument("unknown term")],
            context: context
        )

        #expect(result.contains("**Status**: No results found."))
    }

    @Test("tool parses DuckDuckGo html results")
    func toolParsesDuckDuckGoHTMLResults() throws {
        let html = """
        <div class="result">
          <a href="/l/?kh=-1&amp;uddg=https%3A%2F%2Fexample.com%2Fa%3Fx%3D1%26y%3D2" rel="nofollow" class="result__a highlight">Example &amp; Result</a>
          <a class="result__snippet">A <b>useful</b> summary &amp; details.</a>
        </div>
        """

        let results = WebSearchTool.parseDuckDuckGoHTML(html)

        let result = try #require(results.first)
        #expect(result.title == "Example & Result")
        #expect(result.url == "https://example.com/a?x=1&y=2")
        #expect(result.snippet == "A useful summary & details.")
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginWebSearchLocalization.bundle.url(forResource: "WebSearch", withExtension: "xcstrings") != nil)
        #expect(PluginWebSearchLocalization.string("Web Search").isEmpty == false)
    }
}
