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
    func testPluginExposesSingleGitToolsFactory() async {
        let factories = await GitToolsPlugin.shared.agentToolFactories()

        XCTAssertEqual(factories.count, 1)
        XCTAssertEqual(factories.first?.id, "git.tools.factory")
        XCTAssertEqual(factories.first?.order, 0)
    }
}
#endif
