import AgentToolKit
import Foundation
import LumiCoreKit
import Testing
@testable import BrowserPlugin

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
    @Test("plugin registers browser tools")
    func pluginRegistersTools() {
        let tools = BrowserPlugin.agentTools(
            lumiCore: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        )
        let toolNames = Set(tools.map(\.name))

        #expect(tools.count == 2)
        #expect(toolNames == ["browser_screenshot", "browser_agent"])
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

    @Test("tool accepts uppercase HTTP schemes")
    func toolAcceptsUppercaseHTTPSchemes() throws {
        let httpsURL = try #require(BrowserScreenshotTool.normalizedURL(from: " HTTPS://example.com/page "))
        let httpURL = try #require(BrowserScreenshotTool.normalizedURL(from: "HTTP://example.com/page"))

        #expect(BrowserScreenshotTool.isSupportedHTTPURL(httpsURL))
        #expect(BrowserScreenshotTool.isSupportedHTTPURL(httpURL))
    }

    @Test("tool rejects unsupported URL schemes")
    func toolRejectsUnsupportedURLSchemes() throws {
        let url = try #require(BrowserScreenshotTool.normalizedURL(from: "ftp://example.com/page"))

        #expect(!BrowserScreenshotTool.isSupportedHTTPURL(url))
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

    @Test("tool normalizes JavaScript content heights")
    func toolNormalizesJavaScriptContentHeights() {
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: nil) == 800)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: -10) == 800)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: 0) == 800)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: 1200) == 1200)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: 1200.2) == 1201)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: NSNumber(value: 2400.6)) == 2401)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: " 1600.1 ") == 1601)
        #expect(BrowserScreenshotTool.normalizedContentHeight(from: "not-a-number") == 800)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginBrowserLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(PluginBrowserLocalization.string("Browser").isEmpty == false)
    }

    @Test("browser agent tool schema requires command")
    func browserAgentToolSchemaRequiresCommand() throws {
        let tool = BrowserAgentTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["command"])

        let properties = try #require(schema["properties"] as? [String: [String: Any]])
        #expect(properties["command"]?["type"] as? String == "string")
        #expect(properties["timeout"]?["type"] as? String == "integer")
        #expect(properties["timeout"]?["minimum"] as? Int == 1)
        #expect(properties["timeout"]?["maximum"] as? Int == 300)
    }

    @Test("browser agent tool risk level is medium")
    func browserAgentToolRiskLevel() {
        #expect(BrowserAgentTool().permissionRiskLevel(arguments: [:]) == .medium)
    }

    @Test("browser agent command parser preserves quoted browser arguments")
    func browserAgentCommandParserPreservesQuotedBrowserArguments() {
        #expect(BrowserAgentTool.parseCommandArguments(#"fill @field "hello world""#) == ["fill", "@field", "hello world"])
        #expect(BrowserAgentTool.parseCommandArguments(#"type 'hello world'"#) == ["type", "hello world"])
        #expect(BrowserAgentTool.parseCommandArguments(#"open https://example.com/search\ path"#) == ["open", "https://example.com/search path"])
        #expect(BrowserAgentTool.parseCommandArguments(#"evaluate """#) == ["evaluate", ""])
        #expect(BrowserAgentTool.parseCommandArguments(#"fill @field "unterminated"#) == nil)
    }

    @Test("browser agent timeout is clamped to safe bounds")
    func browserAgentTimeoutIsClampedToSafeBounds() {
        #expect(BrowserAgentTool.normalizedTimeout(nil) == 30)
        #expect(BrowserAgentTool.normalizedTimeout(-10) == 1)
        #expect(BrowserAgentTool.normalizedTimeout(0) == 1)
        #expect(BrowserAgentTool.normalizedTimeout(45) == 45)
        #expect(BrowserAgentTool.normalizedTimeout(45.0) == 45)
        #expect(BrowserAgentTool.normalizedTimeout("45") == 45)
        #expect(BrowserAgentTool.normalizedTimeout(999) == 300)
        #expect(BrowserAgentTool.normalizedTimeout("not-a-number") == 30)
    }
}
