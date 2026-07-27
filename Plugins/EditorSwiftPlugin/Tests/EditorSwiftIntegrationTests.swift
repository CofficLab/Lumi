@testable import EditorSwiftPlugin
import Foundation
import LumiKernel
import Testing

@Test func filterXcodeProjectsKeepsOnlyXcodeRoots() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let xcodeDir = tempDir.appendingPathComponent("XcodeApp")
    try FileManager.default.createDirectory(at: xcodeDir, withIntermediateDirectories: true)
    let xcodeProj = xcodeDir.appendingPathComponent("XcodeApp.xcodeproj", isDirectory: true)
    try FileManager.default.createDirectory(at: xcodeProj, withIntermediateDirectories: true)

    let plainDir = tempDir.appendingPathComponent("PlainFolder")
    try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

    let projects = [
        Project(name: "XcodeApp", path: xcodeDir.path),
        Project(name: "Plain", path: plainDir.path),
    ]

    let filtered = await EditorXcodeProjectPreloader.filterXcodeProjects(projects)
    #expect(filtered.map(\.name) == ["XcodeApp"])
}

@Test func fetchAvailableSchemesUsesFilesystemDiscovery() async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let projectURL = tempDir.appendingPathComponent("Demo.xcodeproj", isDirectory: true)
    let schemesDir = projectURL.appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
    try FileManager.default.createDirectory(at: schemesDir, withIntermediateDirectories: true)
    FileManager.default.createFile(
        atPath: schemesDir.appendingPathComponent("Demo.xcscheme").path,
        contents: Data("<Scheme/>".utf8)
    )

    let schemes = await XcodeSchemeFetcher.fetchAvailableSchemes(for: projectURL)
    #expect(schemes == ["Demo"])
}

@Test func quickOpenCollectRawMatchesFindsXCConfigKeys() throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let configURL = tempDir.appendingPathComponent("Debug.xcconfig")
    try "PRODUCT_NAME = Demo\nSWIFT_VERSION = 5.0".write(to: configURL, atomically: true, encoding: .utf8)

    let matches = XcodeProjectQuickOpenContributor.collectRawMatches(
        query: "product",
        projectRootPath: tempDir.path
    )

    #expect(matches.contains { $0.key == "PRODUCT_NAME" })
    #expect(matches.allSatisfy { $0.isXCConfig })
}

@MainActor
@Test func xcodeProjectContextCapabilityDetectsXcodeProjectRoot() throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let xcodeProj = tempDir.appendingPathComponent("App.xcodeproj", isDirectory: true)
    try FileManager.default.createDirectory(at: xcodeProj, withIntermediateDirectories: true)

    let adapter = XcodeProjectContextCapabilityAdapter()
    #expect(adapter.canHandleProject(at: tempDir.path))
    #expect(adapter.canHandleProject(at: nil) == false)
    #expect(adapter.canHandleProject(at: "   ") == false)
}
