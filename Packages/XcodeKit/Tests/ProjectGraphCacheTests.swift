#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class ProjectGraphCacheTests: XCTestCase {
    func testSaveAndLoadProjectGraph() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectGraphCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let workspace = XcodeWorkspaceContext(
            id: "ws-1",
            name: "App",
            path: URL(fileURLWithPath: "/tmp/App.xcworkspace"),
            projects: [],
            schemes: [
                XcodeSchemeContext(id: "s1", name: "App", buildableTargets: ["App"], defaultConfiguration: "Debug")
            ]
        )

        XCTAssertTrue(ProjectGraphCache.save(workspace, pbxprojHash: "sha256:abc", to: temp))
        let loaded = ProjectGraphCache.load(from: temp, expectedHash: "sha256:abc")
        XCTAssertEqual(loaded?.name, "App")
        XCTAssertEqual(loaded?.schemes.first?.name, "App")
        XCTAssertNil(ProjectGraphCache.load(from: temp, expectedHash: "sha256:other"))
    }
}
#endif
