import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import PluginBrowser

@Suite("PluginBrowser")
struct PluginBrowserTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(BrowserPlugin.id == "Browser")
        #expect(BrowserPlugin.displayName == "Browser")
        #expect(BrowserPlugin.iconName == "safari")
        #expect(BrowserPlugin.category == .general)
        #expect(BrowserPlugin.order == 102)
    }

    @MainActor
    @Test("plugin registers one browser screenshot tool")
    func pluginRegistersTool() {
        let tools = BrowserPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 1)
        #expect(tools.first?.name == "browser_screenshot")
    }

    @Test("tool schema requires url")
    func toolSchemaRequiresURL() throws {
        let tool = BrowserScreenshotTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["url"])

        let properties = try #require(schema["properties"] as? [String: [String: String]])
        #expect(properties["url"]?["type"] == "string")
    }

    @Test("tool risk level is medium")
    func toolRiskLevel() {
        let tool = BrowserScreenshotTool()

        #expect(tool.permissionRiskLevel(arguments: [:]) == .medium)
    }

    @Test("tool trims copied URL whitespace")
    func toolTrimsCopiedURLWhitespace() throws {
        let url = try #require(BrowserScreenshotTool.normalizedURL(from: " \nhttps://example.com/page\t"))

        #expect(url.absoluteString == "https://example.com/page")
    }

    @Test("tool rejects blank copied URL")
    func toolRejectsBlankCopiedURL() {
        #expect(BrowserScreenshotTool.normalizedURL(from: " \n\t ") == nil)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginBrowserLocalization.bundle.url(forResource: "Browser", withExtension: "xcstrings") != nil)
        #expect(PluginBrowserLocalization.string("Browser").isEmpty == false)
    }
}
