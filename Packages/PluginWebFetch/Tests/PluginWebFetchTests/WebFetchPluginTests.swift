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
        #expect(WebFetchPlugin().metadata.policy == .required)
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
        // 回归：缺参曾经返回 "Error: ..." 字符串，默认 executeResult
        // 会把它当成成功结果。
        await #expect(throws: ToolExecutionError.self) {
            _ = try await WebFetchTool().executeResult(arguments: [:])
        }
    }
}
