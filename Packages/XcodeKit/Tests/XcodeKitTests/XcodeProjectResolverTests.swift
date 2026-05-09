import XCTest
@testable import XcodeKit

final class XcodeProjectResolverTests: XCTestCase {

    // MARK: - findWorkspace Tests

    func testFindWorkspaceFindsXCWorkspace() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create .xcworkspace
        let wsURL = tempDir.appendingPathComponent("MyProject.xcworkspace", isDirectory: true)
        try FileManager.default.createDirectory(at: wsURL, withIntermediateDirectories: true)

        // Create .xcodeproj
        let projURL = tempDir.appendingPathComponent("MyProject.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: projURL, withIntermediateDirectories: true)

        let result = XcodeProjectResolver.findWorkspace(in: tempDir)
        XCTAssertEqual(result?.pathExtension, "xcworkspace")
        XCTAssertEqual(result?.lastPathComponent, "MyProject.xcworkspace")
    }

    func testFindWorkspaceFallsBackToXcodeProj() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projURL = tempDir.appendingPathComponent("MyProject.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: projURL, withIntermediateDirectories: true)

        let result = XcodeProjectResolver.findWorkspace(in: tempDir)
        XCTAssertEqual(result?.pathExtension, "xcodeproj")
        XCTAssertEqual(result?.lastPathComponent, "MyProject.xcodeproj")
    }

    func testFindWorkspaceReturnsNilForEmptyDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = XcodeProjectResolver.findWorkspace(in: tempDir)
        XCTAssertNil(result)
    }

    func testFindWorkspaceReturnsNilForNonexistentDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let result = XcodeProjectResolver.findWorkspace(in: tempDir)
        XCTAssertNil(result)
    }

    // MARK: - isXcodeProjectRoot Tests

    func testIsXcodeProjectRootWithWorkspace() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wsURL = tempDir.appendingPathComponent("MyProject.xcworkspace", isDirectory: true)
        try FileManager.default.createDirectory(at: wsURL, withIntermediateDirectories: true)

        XCTAssertTrue(XcodeProjectResolver.isXcodeProjectRoot(tempDir))
    }

    func testIsXcodeProjectRootWithProject() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projURL = tempDir.appendingPathComponent("MyProject.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: projURL, withIntermediateDirectories: true)

        XCTAssertTrue(XcodeProjectResolver.isXcodeProjectRoot(tempDir))
    }

    func testIsNotXcodeProjectRoot() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        XCTAssertFalse(XcodeProjectResolver.isXcodeProjectRoot(tempDir))
    }
}
