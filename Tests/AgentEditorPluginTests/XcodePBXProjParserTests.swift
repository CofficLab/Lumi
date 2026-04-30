#if canImport(XCTest)
import XCTest
@testable import Lumi

final class XcodePBXProjParserTests: XCTestCase {
    func testParseMembershipGraphExtractsTargetRootsAndExclusions() throws {
        let graph = try XcodePBXProjParser.parseMembershipGraph(
            contents: XcodeProjectFixtureFactory.synchronizedRootPBXProj()
        )

        let lumiRoots = try XCTUnwrap(graph.targetRoots["Lumi"])
        XCTAssertEqual(lumiRoots.count, 1)
        XCTAssertEqual(lumiRoots.first?.rootPath, "LumiApp")
        XCTAssertEqual(
            lumiRoots.first?.excludedRelativePaths,
            [
                "Plugins/AgentEditorPlugin/Experimental.swift",
                "Generated/Ignored.swift",
            ]
        )

        let testRoots = try XCTUnwrap(graph.targetRoots["LumiTests"])
        XCTAssertEqual(testRoots.count, 1)
        XCTAssertEqual(testRoots.first?.rootPath, "LumiApp")
        XCTAssertEqual(testRoots.first?.excludedRelativePaths, ["Tests/Disabled.swift"])
    }

    func testParseMembershipGraphReturnsEmptyWhenSectionMissing() throws {
        let graph = try XcodePBXProjParser.parseMembershipGraph(contents: "")
        XCTAssertTrue(graph.targetRoots.isEmpty)
    }
}
#endif
