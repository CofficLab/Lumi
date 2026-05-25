import AgentToolKit
import LumiCoreKit
import Testing
@testable import PluginBrowserAgent

@Suite("PluginBrowserAgent")
struct PluginBrowserAgentTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(BrowserAgentPlugin.id == "BrowserAgent")
        #expect(BrowserAgentPlugin.displayName == "Browser Agent")
        #expect(BrowserAgentPlugin.iconName == "globe")
        #expect(BrowserAgentPlugin.category == .general)
        #expect(BrowserAgentPlugin.order == 103)
    }

    @MainActor
    @Test("plugin registers one browser agent tool")
    func pluginRegistersTool() {
        let tools = BrowserAgentPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 1)
        #expect(tools.first?.name == "browser_agent")
    }

    @Test("tool schema requires command")
    func toolSchemaRequiresCommand() throws {
        let tool = BrowserAgentTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["command"])

        let properties = try #require(schema["properties"] as? [String: [String: String]])
        #expect(properties["command"]?["type"] == "string")
    }

    @Test("tool risk level is medium")
    func toolRiskLevel() {
        let tool = BrowserAgentTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginBrowserAgentLocalization.bundle.url(forResource: "BrowserAgent", withExtension: "xcstrings") != nil)
        #expect(PluginBrowserAgentLocalization.string("Browser Agent").isEmpty == false)
    }
}
