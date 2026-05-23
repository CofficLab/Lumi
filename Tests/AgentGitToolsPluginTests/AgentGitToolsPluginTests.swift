#if canImport(XCTest)
import XCTest
@testable import Lumi

final class AgentGitToolsPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(GitPlugin.id, "GitPlugin")
        XCTAssertEqual(GitPlugin.iconName, "arrow.triangle.branch")
        XCTAssertTrue(GitPlugin.enable)
        XCTAssertFalse(GitPlugin.isConfigurable)
        XCTAssertEqual(GitPlugin.order, 11)
    }

    @MainActor
    func testPluginExposesGitAgentTools() async {
        let context = ToolContext(toolService: ToolService(), llmService: nil, llmVM: nil, conversationVM: nil)
        let tools = await GitPlugin.shared.agentTools(context: context)

        XCTAssertEqual(tools.count, 4)
        XCTAssertEqual(
            Set(tools.map(\.name)),
            ["git_status", "git_diff", "git_log", "git_commit"]
        )
    }
}
#endif
