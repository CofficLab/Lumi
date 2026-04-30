#if canImport(XCTest)
import XCTest
@testable import Lumi

final class EditorWorkspaceSearchControllerTests: XCTestCase {
    func testParseGroupsMatchesByFileAndBuildsSummary() {
        let controller = EditorWorkspaceSearchController()
        let output = """
        {"type":"match","data":{"path":{"text":"/workspace/Sources/App.swift"},"lines":{"text":"let target = value\\n"},"line_number":4,"submatches":[{"start":4}]}}
        {"type":"match","data":{"path":{"text":"/workspace/Sources/App.swift"},"lines":{"text":"target()\\n"},"line_number":7,"submatches":[{"start":0}]}}
        {"type":"match","data":{"path":{"text":"/workspace/Tests/AppTests.swift"},"lines":{"text":"XCTAssertEqual(target, 1)\\n"},"line_number":12,"submatches":[{"start":15}]}}
        """

        let response = controller.parse(
            output: output,
            query: "target",
            projectRootPath: "/workspace"
        )

        XCTAssertEqual(response.summary.query, "target")
        XCTAssertEqual(response.summary.totalMatches, 3)
        XCTAssertEqual(response.summary.totalFiles, 2)
        XCTAssertEqual(response.fileResults.map(\.path), ["Sources/App.swift", "Tests/AppTests.swift"])
        XCTAssertEqual(response.fileResults.first?.matches.first?.column, 5)
    }
}
#endif
