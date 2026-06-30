import LumiCoreKit
import Testing
@testable import WebFetchPlugin

@Suite("PluginWebFetch")
struct PluginWebFetchTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(WebFetchPlugin.id == "WebFetch")
        #expect(WebFetchPlugin.displayName == "Web Fetch")
        #expect(WebFetchPlugin.iconName == "globe")
        #expect(WebFetchPlugin.category == .general)
        #expect(WebFetchPlugin.order == 100)
        #expect(WebFetchPlugin.policy == .optIn)
    }

    @MainActor
    @Test("plugin registers one web fetch tool")
    func pluginRegistersTool() {
        let tools = WebFetchPlugin.agentTools(
            context: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        )

        #expect(tools.count == 1)
        #expect(tools.first?.name == "web_fetch")
    }

    @Test("tool schema requires url")
    func toolSchemaRequiresURL() throws {
        let tool = WebFetchTool()
        let schema = tool.inputSchema

        guard case .object(let keys) = schema else {
            Issue.record("schema should be an object")
            return
        }
        guard case .array(let requiredValues) = keys["required"] else {
            Issue.record("schema should declare required array")
            return
        }
        let required = requiredValues.compactMap { value -> String? in
            if case .string(let s) = value { return s }
            return nil
        }
        #expect(required == ["url"])

        guard case .object(let properties) = keys["properties"],
              case .object(let urlProps) = properties["url"],
              case .string(let urlType) = urlProps["type"] else {
            Issue.record("schema should declare url property type")
            return
        }
        #expect(urlType == "string")
    }

    @Test("tool risk level is medium")
    func toolRiskLevel() {
        let tool = WebFetchTool()

        #expect(tool.riskLevel(arguments: [:], context: nil) == .medium)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginWebFetchLocalization.bundle.url(forResource: "WebFetch", withExtension: "xcstrings") != nil)
        #expect(PluginWebFetchLocalization.string("Web Fetch").isEmpty == false)
    }
}
