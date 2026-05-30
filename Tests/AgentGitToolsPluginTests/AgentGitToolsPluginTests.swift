#if canImport(XCTest)
import XCTest
import LumiCoreKit
@testable import PluginGit
@testable import Lumi

final class AgentGitToolsPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(GitPlugin.id, "GitPlugin")
        XCTAssertEqual(GitPlugin.iconName, "arrow.triangle.branch")
        XCTAssertEqual(GitPlugin.policy, .optIn)
        XCTAssertFalse(GitPlugin.enabledByDefault)
        XCTAssertTrue(GitPlugin.isConfigurable)
        XCTAssertEqual(GitPlugin.order, 11)
    }

    @MainActor
    func testPluginExposesGitAgentTools() async {
        let tools = await GitPlugin.shared.agentTools(context: LumiCoreKit.ToolContext())

        XCTAssertEqual(tools.count, 7)
        XCTAssertEqual(
            Set(tools.map(\.name)),
            [
                "git_status",
                "git_diff",
                "git_log",
                "git_commit",
                "git_show",
                "git_branch",
                "git_unpushed",
            ]
        )
    }
}
#endif
