import XCTest
@testable import XcodeKit

final class XcodeSchemeDiscoveryTests: XCTestCase {

    func testDiscoverSharedSchemesInXcodeProj() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectURL = tempDir.appendingPathComponent("MyApp.xcodeproj", isDirectory: true)
        let schemesDir = projectURL
            .appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
        try FileManager.default.createDirectory(at: schemesDir, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: schemesDir.appendingPathComponent("MyApp.xcscheme").path,
            contents: Data("<Scheme/>".utf8)
        )
        FileManager.default.createFile(
            atPath: schemesDir.appendingPathComponent("MyAppTests.xcscheme").path,
            contents: Data("<Scheme/>".utf8)
        )

        let result = XcodeSchemeDiscovery.discoverSchemeNames(at: projectURL)

        XCTAssertEqual(result, ["MyApp", "MyAppTests"])
    }

    func testDiscoverUserSchemesInXcodeProj() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let projectURL = tempDir.appendingPathComponent("MyApp.xcodeproj", isDirectory: true)
        let userSchemesDir = projectURL
            .appendingPathComponent("xcuserdata/dev.xcuserdatad/xcschemes", isDirectory: true)
        try FileManager.default.createDirectory(at: userSchemesDir, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: userSchemesDir.appendingPathComponent("LocalOnly.xcscheme").path,
            contents: Data("<Scheme/>".utf8)
        )

        let result = XcodeSchemeDiscovery.discoverSchemeNames(at: projectURL)

        XCTAssertEqual(result, ["LocalOnly"])
    }

    func testDiscoverWorkspaceAndSiblingProjectSchemes() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let workspaceURL = tempDir.appendingPathComponent("MyApp.xcworkspace", isDirectory: true)
        let workspaceSchemesDir = workspaceURL
            .appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceSchemesDir, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: workspaceSchemesDir.appendingPathComponent("WorkspaceScheme.xcscheme").path,
            contents: Data("<Scheme/>".utf8)
        )

        let projectURL = tempDir.appendingPathComponent("MyApp.xcodeproj", isDirectory: true)
        let projectSchemesDir = projectURL
            .appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
        try FileManager.default.createDirectory(at: projectSchemesDir, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: projectSchemesDir.appendingPathComponent("MyApp.xcscheme").path,
            contents: Data("<Scheme/>".utf8)
        )

        let result = XcodeSchemeDiscovery.discoverSchemeNames(at: workspaceURL)

        XCTAssertEqual(result, ["WorkspaceScheme", "MyApp"])
    }

    func testDiscoverSchemesFromRealLumiProjectIfPresent() {
        let projectURL = URL(fileURLWithPath: "/Users/angel/Code/Coffic/Lumi/Lumi.xcodeproj")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            return
        }

        let result = XcodeSchemeDiscovery.discoverSchemeNames(at: projectURL)

        XCTAssertTrue(result.contains("Lumi"))
    }
}
