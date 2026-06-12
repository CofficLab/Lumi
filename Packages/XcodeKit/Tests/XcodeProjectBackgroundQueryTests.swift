import XCTest
@testable import XcodeKit

final class XcodeProjectBackgroundQueryTests: XCTestCase {
    func testInspectProjectFindsWorkspaceAndValidBuildServerOffMainActor() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let workspaceURL = tempDir.appendingPathComponent("App.xcworkspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        let canonicalWorkspaceURL = workspaceURL.resolvingSymlinksInPath()

        let storeRoot = tempDir.appendingPathComponent("store", isDirectory: true)
        let store = XcodeBuildServerStore(storageRootURL: storeRoot)
        let buildServerDirectory = store.ensureDirectory(forWorkspace: canonicalWorkspaceURL.path)
        let buildServerURL = buildServerDirectory.appendingPathComponent("buildServer.json")
        let payload: [String: Any] = [
            "workspace": canonicalWorkspaceURL.path,
            "scheme": "App"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: buildServerURL)

        let inspection = await XcodeProjectBackgroundQuery.inspectProject(path: tempDir.path, store: store)

        XCTAssertTrue(inspection.isXcodeProject)
        XCTAssertEqual(inspection.workspaceURL?.resolvingSymlinksInPath(), canonicalWorkspaceURL)
        XCTAssertEqual(inspection.validBuildServerConfig?.workspacePath, canonicalWorkspaceURL.path)
        XCTAssertEqual(inspection.validBuildServerConfig?.scheme, "App")
    }

    func testInspectProjectReturnsNonXcodeForPlainDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let inspection = await XcodeProjectBackgroundQuery.inspectProject(path: tempDir.path)

        XCTAssertFalse(inspection.isXcodeProject)
        XCTAssertNil(inspection.workspaceURL)
        XCTAssertNil(inspection.validBuildServerConfig)
    }

    func testWorkspacePathCandidatesPreserveLookupOrderAndRemoveDuplicates() {
        let workspaceURL = URL(fileURLWithPath: "/private/tmp/App.xcworkspace")

        let candidates = XcodeProjectBackgroundQuery.workspacePathCandidates(for: workspaceURL)

        XCTAssertEqual(candidates.first, "/private/tmp/App.xcworkspace")
        XCTAssertEqual(candidates.last, "/tmp/App.xcworkspace")
        XCTAssertEqual(Set(candidates).count, candidates.count)
    }
}
