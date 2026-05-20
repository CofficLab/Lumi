#if canImport(XCTest)
import XCTest
@testable import Lumi

final class AgentGitToolsPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(GitToolsPlugin.id, "GitTools")
        XCTAssertEqual(GitToolsPlugin.iconName, "git")
        XCTAssertTrue(GitToolsPlugin.enable)
        XCTAssertFalse(GitToolsPlugin.isConfigurable)
        XCTAssertEqual(GitToolsPlugin.order, 16)
    }

    @MainActor
    func testPluginExposesGitAgentTools() async {
        let context = ToolContext(toolService: ToolService(), llmService: nil)
        let tools = await GitToolsPlugin.shared.agentTools(context: context)

        XCTAssertEqual(tools.count, 3)
        XCTAssertEqual(
            Set(tools.map(\.name)),
            ["git_status", "git_diff", "git_log"]
        )
    }
}
#endif
