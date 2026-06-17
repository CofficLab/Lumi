#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class ProjectInputFingerprintTests: XCTestCase {
    func testComputeHashesPbxproj() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectInputFingerprintTests-\(UUID().uuidString)", isDirectory: true)
        let projectURL = temp.appendingPathComponent("App.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(
            at: projectURL.appendingPathComponent("xcshareddata/xcschemes", isDirectory: true),
            withIntermediateDirectories: true
        )
        let pbxproj = projectURL.appendingPathComponent("project.pbxproj")
        try "// fixture".write(to: pbxproj, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        let fingerprints = await ProjectInputFingerprint.compute(workspaceURL: projectURL, schemeName: "App")
        XCTAssertNotNil(fingerprints.pbxprojHash)
        XCTAssertTrue(fingerprints.pbxprojHash?.hasPrefix("sha256:") == true)
    }
}
#endif
