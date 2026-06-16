import XCTest
@testable import XcodeKit

final class XcodeTargetMembershipTests: XCTestCase {

    func testLumiProjectIncludesAppBootstrapInTarget() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectURL = repoRoot.appendingPathComponent("Lumi.xcodeproj")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw XCTSkip("Lumi.xcodeproj is unavailable in this environment")
        }

        let result = XcodeProjectResolver.resolveTargetSourceFiles(projectLikeURL: projectURL)
        let appBootstrap = XcodeProjectResolver.normalizedMembershipPath(
            for: repoRoot.appendingPathComponent("LumiApp/Bootstrap/AppBootstrap.swift")
        )

        XCTAssertTrue(
            result["Lumi"]?.contains(appBootstrap) == true,
            "Expected AppBootstrap.swift to belong to Lumi target"
        )
    }

    func testNormalizedMembershipPathTreatsEquivalentPathsAsEqual() {
        XCTAssertEqual(
            XcodeProjectResolver.normalizedMembershipPath(for: URL(fileURLWithPath: "/var")),
            XcodeProjectResolver.normalizedMembershipPath(for: URL(fileURLWithPath: "/private/var"))
        )
        XCTAssertEqual(
            XcodeProjectResolver.normalizedMembershipPath(for: URL(fileURLWithPath: "/tmp")),
            XcodeProjectResolver.normalizedMembershipPath(for: URL(fileURLWithPath: "/private/tmp"))
        )
    }

    func testTargetMembershipMatchesSymlinkedLookupPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let realFile = root.appendingPathComponent("AppBootstrap.swift")
        try "enum AppBootstrap {}".write(to: realFile, atomically: true, encoding: .utf8)

        let aliasRoot = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(
            at: aliasRoot,
            withDestinationURL: realFile.deletingLastPathComponent()
        )

        let lookupURL = aliasRoot.appendingPathComponent("AppBootstrap.swift")
        let storedPath = XcodeProjectResolver.normalizedMembershipPath(for: realFile)

        XCTAssertTrue(
            XcodeProjectResolver.targetMembershipContains(
                fileURL: lookupURL,
                sourceFiles: [storedPath]
            )
        )
    }

    func testPlaceholderWorkspaceIncludesAppBootstrapInTarget() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectURL = repoRoot.appendingPathComponent("Lumi.xcodeproj")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw XCTSkip("Lumi.xcodeproj is unavailable in this environment")
        }

        let targetSourceFiles = XcodeProjectResolver.resolveTargetSourceFiles(projectLikeURL: projectURL)
        let placeholder = XcodeProjectResolver.makePlaceholderWorkspaceContext(
            workspaceURL: projectURL,
            schemeNames: ["Lumi"],
            targetSourceFiles: targetSourceFiles
        )
        let appBootstrap = XcodeProjectResolver.normalizedMembershipPath(
            for: repoRoot.appendingPathComponent("LumiApp/Bootstrap/AppBootstrap.swift")
        )

        let lumiTarget = placeholder.projects.first?.targets.first(where: { $0.name == "Lumi" })
        XCTAssertTrue(lumiTarget?.sourceFiles.contains(appBootstrap) == true)
    }

    @MainActor
    func testOpenLumiProjectFindsAppBootstrapInTarget() async throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectURL = repoRoot.appendingPathComponent("Lumi.xcodeproj")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw XCTSkip("Lumi.xcodeproj is unavailable in this environment")
        }

        let store = XcodeBuildServerStore(
            storageRootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        let provider = XcodeBuildContextProvider(store: store)
        await provider.openProject(at: projectURL)

        let appBootstrap = repoRoot.appendingPathComponent("LumiApp/Bootstrap/AppBootstrap.swift")
        let matches = provider.findTargetsForFile(fileURL: appBootstrap)

        XCTAssertEqual(matches.map(\.name), ["Lumi"])
    }
}
