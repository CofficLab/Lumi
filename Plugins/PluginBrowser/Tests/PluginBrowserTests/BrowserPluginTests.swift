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

        let properties = try #require(schema["properties"] as? [String: [String: Any]])
        #expect(properties["url"]?["type"] as? String == "string")
    }

    @Test("tool schema bounds screenshot dimensions")
    func toolSchemaBoundsScreenshotDimensions() throws {
        let schema = BrowserScreenshotTool().inputSchema(for: .english)
        let properties = try #require(schema["properties"] as? [String: [String: Any]])
        let width = try #require(properties["width"])
        let wait = try #require(properties["wait"])

        #expect(width["minimum"] as? Int == 1)
        #expect(width["maximum"] as? Int == 4096)
        #expect(wait["minimum"] as? Int == 0)
        #expect(wait["maximum"] as? Int == 10)
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

    @Test("tool normalizes unsafe viewport widths")
    func toolNormalizesUnsafeViewportWidths() {
        #expect(BrowserScreenshotTool.normalizedViewportWidth(from: nil) == 1280)
        #expect(BrowserScreenshotTool.normalizedViewportWidth(from: -100) == 1280)
        #expect(BrowserScreenshotTool.normalizedViewportWidth(from: 0) == 1280)
        #expect(BrowserScreenshotTool.normalizedViewportWidth(from: 1440) == 1440)
        #expect(BrowserScreenshotTool.normalizedViewportWidth(from: 8192) == 4096)
        #expect(BrowserScreenshotTool.normalizedViewportWidth(from: " 1024 ") == 1024)
    }

    @Test("tool normalizes wait seconds")
    func toolNormalizesWaitSeconds() {
        #expect(BrowserScreenshotTool.normalizedWaitSeconds(from: nil) == 1.0)
        #expect(BrowserScreenshotTool.normalizedWaitSeconds(from: -2.0) == 0)
        #expect(BrowserScreenshotTool.normalizedWaitSeconds(from: 0.25) == 0.25)
        #expect(BrowserScreenshotTool.normalizedWaitSeconds(from: 99) == 10)
        #expect(BrowserScreenshotTool.normalizedWaitSeconds(from: " 2.5 ") == 2.5)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginBrowserLocalization.bundle.url(forResource: "Browser", withExtension: "xcstrings") != nil)
        #expect(PluginBrowserLocalization.string("Browser").isEmpty == false)
    }
}
