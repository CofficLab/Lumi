#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class SemanticIndexFixtureIntegrationTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MinimalApp.xcodeproj", isDirectory: true)
    }

    func testFixtureExistsAndIsDiscoverableFromParentDirectory() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixtureURL.path))
        let fixturesRoot = fixtureURL.deletingLastPathComponent()
        XCTAssertTrue(XcodeProjectResolver.isXcodeProjectRoot(fixturesRoot))
    }

    func testProjectGraphCacheRoundTripForFixture() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticIndexFixtureIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let workspace = XcodeWorkspaceContext(
            id: "fixture",
            name: "MinimalApp",
            path: fixtureURL,
            projects: [],
            schemes: [XcodeSchemeContext(id: "s1", name: "MinimalApp", buildableTargets: ["MinimalApp"], defaultConfiguration: "Debug")]
        )
        let hash = "sha256:fixture"
        XCTAssertTrue(ProjectGraphCache.save(workspace, pbxprojHash: hash, to: temp))
        XCTAssertEqual(ProjectGraphCache.load(from: temp, expectedHash: hash)?.name, "MinimalApp")
    }

    @MainActor
    func testManifestCacheHitSkipsRebuildDecision() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticIndexFixtureIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let store = XcodeBuildServerStore(pluginDirectoryURL: temp)
        let workspacePath = fixtureURL.path
        _ = store.ensureDirectory(forWorkspace: workspacePath)

        let inputs = await ProjectInputFingerprint.compute(workspaceURL: fixtureURL, schemeName: "MinimalApp")
        let toolchain = ProjectInputFingerprint.currentToolchain()
        let compileURL = store.compileDatabaseURL(forWorkspace: workspacePath)
        let entries: [[String: Any]] = [
            ["module_name": "MinimalApp", "command": "swiftc -module-name MinimalApp "]
        ]
        try JSONSerialization.data(withJSONObject: entries).write(to: compileURL)

        let manifest = IndexManifest(
            workspacePath: workspacePath,
            scheme: "MinimalApp",
            configuration: "Debug",
            destination: "platform=macOS",
            inputs: inputs,
            toolchain: toolchain,
            compileDatabase: IndexManifest.CompileDatabaseInfo(entryCount: 1, includesSchemeModule: true)
        )
        XCTAssertTrue(store.saveManifest(manifest, forWorkspace: workspacePath))

        XCTAssertTrue(
            IndexManifestValidation.isCompileDatabaseValid(
                manifest: store.loadManifest(forWorkspace: workspacePath),
                compileDatabaseURL: compileURL,
                scheme: "MinimalApp",
                configuration: "Debug",
                destination: "platform=macOS",
                inputs: inputs,
                toolchain: toolchain
            )
        )

        let strategy = SemanticIndexRebuildPolicy.strategy(
            manifest: manifest,
            inputs: inputs,
            scheme: "MinimalApp",
            configuration: "Debug",
            destination: "platform=macOS"
        )
        XCTAssertEqual(strategy, .skip)
    }
}
#endif
